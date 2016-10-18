(* This file was generated by Ocsigen-start.
   Feel free to use it, modify it, and redistribute it as you wish. *)

(** calendar demo **********************************************************)

[%%shared
  open Eliom_content.Html
  open Eliom_content.Html.D
]

let%server service =
  Eliom_service.create
    ~path:(Eliom_service.Path ["demo-calendar"])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    ()

let%client service = ~%service

let%server s, f = Eliom_shared.React.S.create None

let%client action y m d = ~%f (Some (y, m, d)); Lwt.return ()

let%shared string_of_date = function
  | Some (y, m, d) ->
    Printf.sprintf "You clicked on %d %d %d" y m d
  | None ->
    ""

let%server date_as_string () : string Eliom_shared.React.S.t =
  Eliom_shared.React.S.map [%shared string_of_date] s

let%server date_reactive () = Lwt.return @@ date_as_string ()

let%client date_reactive =
  ~%(Eliom_client.server_function [%derive.json: unit] date_reactive)


let%shared name = "Calendar"

let%shared page () =
  let calendar = Ot_calendar.make
      ~click_non_highlighted:true
      ~action:[%client action]
      ()
  in
  let%lwt dr = date_reactive () in
  Lwt.return
    [
      p [pcdata "This page shows the calendar."];
      div ~a:[a_class ["os-calendar"]] [calendar];
      p [Eliom_content.Html.R.pcdata dr]
    ]
