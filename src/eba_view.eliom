(* Copyright University paris Diderot *)
(* Do not hesitate to copy paste part of this code, modify it,
   and integrate it in your app to customize the behaviour according to
   your needs. *)

[%%shared
  open Eliom_content.Html5
  open Eliom_content.Html5.F

let generic_email_form ?a ?label ?(text="Send") ~service () =
  D.Form.post_form ?a ~service
    (fun name ->
      let l = [
        Form.input
          ~a:[a_placeholder "e-mail address"]
          ~input_type:`Email
          ~name
          Form.string;
        Form.input
          ~a:[a_class ["button"]]
          ~input_type:`Submit
          ~value:text
          Form.string;
      ]
      in
      match label with
        | None -> l
        | Some lab -> F.label [pcdata lab]::l) ()

let connect_form ?a () =
  D.Form.post_form ?a ~xhr:false ~service:Eba_services.connect_service
    (fun ((login, password), keepmeloggedin) -> [
      Form.input
        ~a:[a_placeholder "Your email"]
        ~name:login
        ~input_type:`Email
        Form.string;
      Form.input
        ~a:[a_placeholder "Your password"]
        ~name:password
        ~input_type:`Password
        Form.string;
      Form.bool_checkbox_one
        ~a:[a_checked]
        ~name:keepmeloggedin
        ();
      span [pcdata "keep me logged in"];
      Form.input
        ~a:[a_class ["button"]]
        ~input_type:`Submit
        ~value:"Sign in"
        Form.string;
    ]) ()

]

[%%shared
let disconnect_button ?a () =
  Form.post_form ?a ~service:Eba_services.disconnect_service
    (fun _ -> [
         Form.button_no_value ~button_type:`Submit
           [Ow_icons.F.signout (); pcdata "Logout"]
       ]) ()

let sign_up_form ?a () =
  generic_email_form ?a ~service:Eba_services.sign_up_service' ()

let forgot_password_form ?a () =
  generic_email_form ?a
    ~service:Eba_services.forgot_password_service ()

let information_form ?a
    ?(firstname="") ?(lastname="") ?(password1="") ?(password2="")
    () =
  D.Form.post_form ?a ~service:Eba_services.set_personal_data_service'
    (fun ((fname, lname), (passwordn1, passwordn2)) ->
       let pass1 = D.Form.input
           ~a:[a_placeholder "Your password"]
           ~name:passwordn1
           ~value:password1
           ~input_type:`Password
           Form.string
       in
       let pass2 = D.Form.input
           ~a:[a_placeholder "Re-enter password"]
           ~name:passwordn2
           ~value:password2
           ~input_type:`Password
           Form.string
       in
       let _ = [%client (
         let pass1 = To_dom.of_input ~%pass1 in
         let pass2 = To_dom.of_input ~%pass2 in
         Lwt_js_events.(async (fun () ->
           inputs pass2 (fun _ _ ->
             if (Js.to_string pass1##.value <> Js.to_string pass2##.value)
             then (Js.Unsafe.coerce pass2)##(setCustomValidity
                 ("Passwords do not match"))
             else (Js.Unsafe.coerce pass2)##(setCustomValidity (""));
             Lwt.return ())))
       : unit)]
       in
       [
         Form.input
           ~a:[a_placeholder "Your first name"]
           ~name:fname
           ~value:firstname
           ~input_type:`Text
           Form.string;
         Form.input
           ~a:[a_placeholder "Your last name"]
           ~name:lname
           ~value:lastname
           ~input_type:`Text
           Form.string;
         pass1;
         pass2;
         Form.input
           ~a:[a_class ["button"]]
           ~input_type:`Submit
           ~value:"Submit"
           Form.string;
       ]) ()


let preregister_form ?a label =
  generic_email_form ?a ~service:Eba_services.preregister_service' ~label ()

let home_button ?a () =
  Form.get_form ?a ~service:Eba_services.main_service
    (fun _ -> [
      Form.input
        ~input_type:`Submit
        ~value:"home"
        Form.string;
    ])

let avatar user =
  match Eba_user.avatar_uri_of_user user with
  | Some src ->
    img ~alt:"picture" ~a:[a_class ["eba_avatar"]] ~src ()
  | None -> Ow_icons.F.user ()

let username user =
  let n = match Eba_user.firstname_of_user user with
    | "" ->
      let userid = Eba_user.userid_of_user user in
      [pcdata ("User "^Int64.to_string userid)]
    | s ->
      [pcdata s;
       pcdata " ";
       pcdata (Eba_user.lastname_of_user user);
      ]
  in
  div ~a:[a_class ["eba_username"]] n

let password_form ?a ~service () =
  D.Form.post_form
    ?a
    ~service
    (fun (pwdn, pwd2n) ->
       let pass1 =
         D.Form.input
           ~a:[a_required; a_autocomplete false]
           ~input_type:`Password ~name:pwdn
           Form.string
       in
       let pass2 =
         D.Form.input
           ~a:[a_required; a_autocomplete false]
           ~input_type:`Password ~name:pwd2n
           Form.string
       in
       ignore [%client (
         let pass1 = To_dom.of_input ~%pass1 in
         let pass2 = To_dom.of_input ~%pass2 in
         Lwt_js_events.async
           (fun () ->
              Lwt_js_events.inputs pass2
                (fun _ _ ->
                   ignore
                     (if Js.to_string pass1##.value <> Js.to_string pass2##.value
                      then
                        (Js.Unsafe.coerce
                           pass2)##(setCustomValidity ("Passwords do not match"))
                      else (Js.Unsafe.coerce pass2)##(setCustomValidity ("")));
                   Lwt.return ()))
       : unit)];
       [
         table
           [
             tr [td [label [pcdata "Password:"]]; td [pass1]];
             tr [td [label [pcdata "Retype password:"]]; td [pass2]];
           ];
         Form.input ~input_type:`Submit ~value:"Send" Form.string
       ])
    ()
 ]
