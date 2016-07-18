(* This file was generated by Eliom-base-app.
   Feel free to use it, modify it, and redistribute it as you wish. *)

(** This module defines the default template for application pages *)

let%shared eba_header ?user () = Eliom_content.Html.F.(
  ignore user;
  let%lwt user_box = 
    %%%MODULE_NAME%%%_userbox.userbox user %%%MODULE_NAME%%%_services.upload_user_avatar_service in
  let%lwt navigation_bar = %%%MODULE_NAME%%%_navigationbar.navigationbar () in
  Lwt.return (
    nav ~a:[a_class ["navbar";"navbar-inverse";"navbar-relative-top"]] [
      div ~a:[a_class ["container-fluid"]] [
	div ~a:[a_class ["navbar-header"]][
	  a ~a:[a_class ["navbar-brand"]]
            ~service:Eba_services.main_service [
	      pcdata %%%MODULE_NAME%%%_base.application_name;
	    ] ();
	  user_box
	];
	navigation_bar
      ]
    ]
  )
)

let%shared eba_footer () = Eliom_content.Html.F.(
  footer ~a:[a_class ["footer";"navbar";"navbar-inverse"]] [
    div ~a:[a_class ["container"]] [
      p [
	pcdata "This application has been generated using the ";
	a ~service:Eba_services.eba_github_service [
	  pcdata "Eliom-base-app"
	] ();
	pcdata " template for Eliom-distillery and uses the ";
	a ~service:Eba_services.ocsigen_service [
	  pcdata "Ocsigen"
	] ();
	pcdata " technology.";
      ]
    ]
  ]
)

let%server connected_welcome_box () = Eliom_content.Html.F.(
  let info, ((fn, ln), (p1, p2)) =
    match Eliom_reference.Volatile.get Eba_msg.wrong_pdata with
    | None ->
      p [
        pcdata "Your personal information has not been set yet.";
        br ();
        pcdata "Please take time to enter your name and to set a password."
      ], (("", ""), ("", ""))
    | Some wpd -> p [pcdata "Wrong data. Please fix."], wpd
  in
  div ~a:[a_id "eba_welcome_box"] [
    div [h2 [pcdata ("Welcome!")]; info];
    Eba_view.information_form
      ~firstname:fn ~lastname:ln
      ~password1:p1 ~password2:p2
      ()
  ]
)


let%server page userid_o content = Eliom_content.Html.F.(
  let%lwt user =
    match userid_o with
    | None ->
      Lwt.return None
    | Some userid ->
      let%lwt u = Eba_user_proxy.get_data userid in
      Lwt.return (Some u)
  in
  let content = match user with
    | Some user when not (Eba_user.is_complete user) ->
      %%%MODULE_NAME%%%_welcomebox.connected_welcome_box () :: content
    | _ ->
      content
  in
  let l = [
    div ~a:[a_class ["eba_body"]] content;
    eba_footer ();
  ] in
  let%lwt h = eba_header ?user () in
  Lwt.return @@ h :: l
)

let%client page _ content = Eliom_content.Html.F.(
  let l = [
    div ~a:[a_class ["eba_body"]] content;
    eba_footer ();
  ] in
  let%lwt h = eba_header () in Lwt.return (h :: l)
)
