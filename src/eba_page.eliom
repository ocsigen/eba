(* Eliom-base-app
 * http://www.ocsigen.org/eliom-base-app
 *
 * Copyright (C) 2014
 *      Charly Chevalier
 *      Vincent Balat
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)
[%%shared
  open Eliom_content.Html5
  open Eliom_content.Html5.F

exception Predicate_failed of (exn option)

type content =
  {title: string option;
   head : Html5_types.head_content_fun elt list;
   body_attrs : Html5_types.body_attrib Eliom_content.Html5.attrib list;
   body : Html5_types.body_content elt list}

let content ?(a=[]) ?title ?(head = []) body =
  { title;
    head = (head :> Html5_types.head_content_fun elt list);
    body_attrs = a;
    body = (body :> Html5_types.body_content elt list)}

module type PAGE = sig
  val title : string
  val js : string list list
  val local_js : string list list
  val css : string list list
  val local_css : string list list
  val other_head : Html5_types.head_content_fun Eliom_content.Html5.elt list
  val default_error_page :
    'a -> 'b -> exn ->
    Html5_types.body_content Eliom_content.Html5.elt list Lwt.t
  val default_error_page_full : ('a -> 'b -> exn -> content Lwt.t) option
  val default_connected_error_page :
    int64 option -> 'a -> 'b -> exn ->
    Html5_types.body_content Eliom_content.Html5.elt list Lwt.t
  val default_connected_error_page_full :
    (int64 option -> 'a -> 'b -> exn -> content Lwt.t) option
  val default_predicate : 'a -> 'b -> bool Lwt.t
  val default_connected_predicate : int64 option -> 'a -> 'b -> bool Lwt.t
end

module Default_config = struct
  let title = ""
  let js : string list list = []
  let css : string list list = []
  let local_js : string list list = []
  let local_css : string list list = []
  let other_head : Html5_types.head_content_fun Eliom_content.Html5.elt list
    = []

  let err_page exn =
    let de = if ~%(Ocsigen_config.get_debugmode ())
             then [p [pcdata "Debug info: ";
                      em [pcdata (Printexc.to_string exn)]]]
             else []
    in
    let l = match exn with
      | Eba_session.Not_connected ->
        p [pcdata "You must be connected to see this page."]::de
      | _ -> de
    in
    Lwt.return [div ~a:[a_class ["errormsg"]] (h2 [pcdata "Error"]::l)]

  let default_predicate _ _ = Lwt.return true
  let default_connected_predicate _ _ _ = Lwt.return true
  let default_error_page _ _ exn = err_page exn
  let default_error_page_full = None
  let default_connected_error_page _ _ _ exn = err_page exn
  let default_connected_error_page_full = None

end

module Make(C : PAGE) = struct

  let css =
    List.map
      (fun cssname -> ("css"::cssname))
      C.css

  let js =
    List.map
      (fun jsname -> ("js"::jsname))
      C.js

  (* Local assets always have relative links. *)
  let local_css =
    List.map
      (fun cssname ->
         Eliom_content.Html5.F.css_link
           ~uri:(make_uri
                   ~absolute:false
                   ~service:(Eliom_service.static_dir ())
                   ("css"::cssname)) () )
      C.local_css

  let local_js =
    List.map
      (fun cssname ->
         Eliom_content.Html5.F.js_script
           ~uri:(make_uri
                   ~absolute:false
                   ~service:(Eliom_service.static_dir ())
                   ("js"::cssname)) () )
      C.local_js

  let make_page_full content =
    let title = match content.title with Some t -> t | None -> C.title in
    html
      (Eliom_tools.F.head ~title ~css ~js
         ~other:(local_css @ local_js @ content.head @ C.other_head) ())
      (body ~a:content.body_attrs content.body)

  let make_page body = make_page_full (content body)

  let wrap_fallback fallback gp pp exc_opt =
    let%lwt body = fallback gp pp exc_opt in Lwt.return (content body)

  let default_error_page =
    match C.default_error_page_full with
      Some default ->
        default
    | None ->
        fun gp pp exc_opt -> wrap_fallback C.default_error_page gp pp exc_opt

  let page_full
      ?(predicate = C.default_predicate)
      ?(fallback = default_error_page)
      f gp pp =
    let%lwt content =
      try%lwt
        let%lwt b = predicate gp pp in
        if b then
          try%lwt f gp pp
          with exc -> fallback gp pp exc
        else fallback gp pp (Predicate_failed None)
      with exc -> fallback gp pp (Predicate_failed (Some exc))
    in
    Lwt.return (make_page_full content)

  let page ?predicate ?fallback f =
    page_full ?predicate
      ?fallback:(match fallback with
                   None          -> None
                 | Some fallback -> Some (wrap_fallback fallback))
      (fun gp pp -> let%lwt body = f gp pp in Lwt.return (content body))

  let wrap_fallback_2 fallback uid_opt gp pp exc_opt =
    let%lwt body = fallback uid_opt gp pp exc_opt in Lwt.return (content body)

  let default_connected_error_page =
    match C.default_connected_error_page_full with
      Some default ->
        default
    | None ->
        fun uid_opt gp pp exc_opt ->
          wrap_fallback_2 C.default_connected_error_page uid_opt gp pp exc_opt

  let connected_page_full
      ?allow ?deny
      ?(predicate = C.default_connected_predicate)
      ?(fallback = default_connected_error_page)
      f gp pp =
    let f_wrapped uid gp pp =
      try%lwt
        let%lwt b = predicate (Some uid) gp pp in
        if b then
          try%lwt f uid gp pp
          with exc -> fallback (Some uid) gp pp exc
        else Lwt.fail (Predicate_failed None)
      with
        | (Predicate_failed _) as exc -> fallback (Some uid) gp pp exc
        | exc -> fallback (Some uid) gp pp (Predicate_failed (Some exc))
    in
    let%lwt content =
      try%lwt
        Eba_session.connected_fun ?allow ?deny
          ~deny_fun:(fun uid_o ->
            fallback uid_o gp pp Eba_session.Permission_denied)
          f_wrapped gp pp
      with Eba_session.Not_connected as exc -> fallback None gp pp exc
    in
    Lwt.return (make_page_full content)

  let connected_page ?allow ?deny ?predicate ?fallback f gp pp =
    connected_page_full
      ?allow ?deny
      ?predicate
      ?fallback:(match fallback with
                   None          -> None
                 | Some fallback -> Some (wrap_fallback_2 fallback))
      (fun uid_opt gpp pp ->
         let%lwt body = f uid_opt gp pp in Lwt.return (content body))
      gp pp

  module Opt = struct

    let connected_page_full
        ?allow ?deny
        ?(predicate = C.default_connected_predicate)
        ?(fallback = default_connected_error_page)
        f gp pp =
      let f_wrapped (uid_o : int64 option) gp pp =
        try%lwt
          let%lwt b = predicate uid_o gp pp in
          if b then
            try%lwt f uid_o gp pp
            with exc -> fallback uid_o gp pp exc
          else Lwt.fail (Predicate_failed None)
        with
          | (Predicate_failed _) as exc -> fallback uid_o gp pp exc
          | exc -> fallback uid_o gp pp (Predicate_failed (Some exc))
      in
      let%lwt content = Eba_session.Opt.connected_fun
        ?allow ?deny
        ~deny_fun:(fun uid_o ->
          fallback uid_o gp pp Eba_session.Permission_denied)
        f_wrapped gp pp
      in
      Lwt.return (make_page_full content)

    let connected_page ?allow ?deny ?predicate ?fallback f gp pp =
      connected_page_full
        ?allow ?deny
        ?predicate
        ?fallback:(match fallback with
                     None          -> None
                   | Some fallback -> Some (wrap_fallback_2 fallback))
        (fun uid_opt gpp pp ->
           let%lwt body = f uid_opt gp pp in Lwt.return (content body))
        gp pp

  end
end
]
