(* Ocsigen-start
 * http://www.ocsigen.org/ocsigen-start
 *
 * Copyright (C) Université Paris Diderot, CNRS, INRIA, Be Sport.
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
  open Eliom_content.Html
  open Eliom_content.Html.F
]

[%%shared
  type uploader = (unit,unit) Ot_picture_uploader.service
]

let wrong_password =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope false

let user_already_exists =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope false

let user_does_not_exist =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope false

let user_already_preregistered =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope false

let activation_key_outdated =
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope false

let%shared upload_pic_link
    ?(a = [])
    ?(content=[pcdata "Change profile picture"])
    ?(crop = Some 1.)
    ?(input :
      Html_types.label_attrib Eliom_content.Html.D.Raw.attrib list
      * Html_types.label_content_fun Eliom_content.Html.D.Raw.elt list
      = [], []
    )
    ?(submit :
      Html_types.button_attrib Eliom_content.Html.D.Raw.attrib list
      * Html_types.button_content_fun Eliom_content.Html.D.Raw.elt list
      = [], [pcdata "Submit"]
    )
    (close : (unit -> unit) Eliom_client_value.t)
    (service : uploader)
    userid =
  let content = (content
                 : Html_types.a_content Eliom_content.Html.D.Raw.elt list) in
  D.Raw.a ~a:( a_onclick [%client (fun ev -> Lwt.async (fun () ->
    ~%close () ;
    let upload ?progress ?cropping file =
      Ot_picture_uploader.ocaml_service_upload
        ?progress ?cropping ~service:~%service ~arg:() file in
    try%lwt ignore @@
      Ot_popup.popup
        ~close_button:[ Ot_icons.F.close () ]
        ~onclose:(fun () ->
          Eliom_client.change_page
            ~service:Eliom_service.reload_action () ())
        (fun close -> Ot_picture_uploader.mk_form
            ~crop:~%crop ~input:~%input ~submit:~%submit
            ~after_submit:close upload) ;
      Lwt.return ()
    with e ->
      Os_msg.msg ~level:`Err "Error while uploading the picture";
      Eliom_lib.debug_exn "%s" e "→ ";
      Lwt.return () ) : _ ) ] :: a) content

let%shared reset_tips_service = Os_tips.reset_tips_service

let%shared reset_tips_link close =
  let l = D.Raw.a [pcdata "See help again from beginning"] in
  ignore [%client (
    Lwt_js_events.(async (fun () ->
      clicks (To_dom.of_element ~%l)
        (fun _ _ ->
           ~%close ();
           Eliom_client.exit_to
             ~service:reset_tips_service
             () ();
           Lwt.return ()
        )));
  : unit)];
  l

let%shared user_menu_ close user service =
  [
    p [pcdata "Change your password:"];
    Os_view.password_form ~service:Os_services.set_password_service' ();
    hr ();
    upload_pic_link close service (Os_user.userid_of_user user);
    hr ();
    reset_tips_link close;
    hr ();
    Os_view.disconnect_button ();
  ]

let%client user_menu_fun =
  ref (user_menu_
       : (unit -> unit) ->
       'a -> 'b -> Html_types.div_content Eliom_content.Html.elt list)

let%shared user_menu user service =
  let but = D.div ~a:[a_class ["os_usermenu_button"]]
      [Ot_icons.F.config ~a:[a_class ["fa-large"]] ()]
  in
  let menu = D.div [] in
  ignore
    (Ow_button.button_dyn_alert but menu
       [%client (fun _ _ ->
          let close () =
            let o = Ow_button.to_button_dyn_alert ~%but in
            o##unpress
          in
          Lwt.return (!user_menu_fun close ~%user ~%service): 'a -> 'b)]);
  div ~a:[a_class ["os_usermenu"]] [but; menu]

let%client set_user_menu f = user_menu_fun := f

let%shared connected_user_box user (service : uploader) =
  let username = Os_view.username user in
  D.div ~a:[a_id "os-user-box"] [
    Os_view.avatar user;
    username;
    user_menu user service;
  ]

   (* Module Ow_active_set is to be rewritten completely and simplified.
      Then we can remove this. *)
let%server make_set () =
   [%client (
     Ow_active_set.to_server_set
       (Ow_active_set.set ~at_least_one:true ())
   : Ow_active_set.t')]

let%client make_set () =
  Ow_active_set.set ~at_least_one:true ()

let%shared connection_box_id = "os_login_signup_box"

let%shared connection_box_ () =
  let set = make_set () in
  let button1 = D.h2 [pcdata "Login"] in
  let form1 = Os_view.connect_form () in
  let o1,_ =
    Ow_button.button_alert
      ~set
      ~pressed:true
      button1
      form1
  in
  let button2 = D.h2 [pcdata "Lost password"] in
  let form2 = Os_view.forgot_password_form () in
  let o2,_ =
    Ow_button.button_alert
      ~set:set
      button2
      form2
  in
  let button3 = D.h2 [pcdata "Preregister"] in
  let form3 =
    Os_view.preregister_form
      "Enter your e-mail address to get informed when the site opens \
       and be one of the first users"
  in
  let o3,_ =
    Ow_button.button_alert
      ~set
      button3
      form3
  in
  let button4 = D.h2 [pcdata "Register"] in
  let form4 = Os_view.sign_up_form () in
  let o4,_ =
    Ow_button.button_alert
      ~set
      button4
      form4
  in
  let d =
    (* If the registration is not open (pre-registration only): *)
    (* D.div ~a:[a_id id] *)
    (*   [button1; button3; button2; form1; form3; form2] *)
    (* and handle_rmsg is display_error o3 *)
    (* otherwise *)
    D.div ~a:[a_id connection_box_id]
      [button1; button2; button4; form1; form2; form4]
  in
  Lwt.return (d, o1, o2, o3, o4)

let%client connection_box () =
  let%lwt a, _, _, _, _ = connection_box_ () in
  Lwt.return a

let%server connection_box () =
  if Eliom_reference.Volatile.get Os_msg.activation_key_created
  then
    Lwt.return
      (D.div ~a:[a_id connection_box_id]
         [p [pcdata "An email has been sent to this address. ";
             pcdata "Click on the link it contains to log in."]])
  else
    let%lwt d, o1, o2, o3, o4 = connection_box_ () in
    (* function to press the corresponding button and display
     * the flash message error. *)
    let press but =
      ignore [%client (
        ((Ow_button.to_button_alert ~%but))##press;
      : unit)];
      Lwt.return ()
    in
    (* Function to display flash message error *)
    let display_error o34 () =
      let wrong_password = Eliom_reference.Volatile.get wrong_password in
      let user_already_exists = Eliom_reference.Volatile.get user_already_exists
      in
      let user_does_not_exist = Eliom_reference.Volatile.get user_does_not_exist
      in
      let user_already_preregistered =
        Eliom_reference.Volatile.get user_already_preregistered
      in
      let activation_key_outdated =
        Eliom_reference.Volatile.get activation_key_outdated
      in

      if wrong_password
      then press o1
      else if activation_key_outdated
      then press o2
      else if user_already_exists
      then press o34
      else if user_does_not_exist
      then press o2
      else if user_already_preregistered
      then press o3
      else Lwt.return ()
    in

    (* function to handle specific flash messages *)
    let handle_rmsg = display_error o4 in
    let%lwt () = handle_rmsg () in
    Lwt.return d

let%shared userbox user service =
  match user with
  | Some user -> Lwt.return (connected_user_box user service)
  | None -> connection_box ()
