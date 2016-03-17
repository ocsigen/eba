(* Feel free to modify and/or redistribute this file as you wish. *)

[%%shared

let section = Lwt_log.Section.make "eba:current_user"

type current_user =
  | CU_idontknown
  | CU_notconnected
  | CU_user of Eba_user.t

let please_use_connected_fun =
  "Eba_current_user is usable only with connected functions"

]

(* current user *)
let me : current_user Eliom_reference.Volatile.eref =
  (* This is a request cache of current user *)
  Eliom_reference.Volatile.eref ~scope:Eliom_common.request_scope CU_idontknown

[%%client

let me : current_user ref = ref CU_notconnected
  (*on client side the default is not connected *)

let get_current_user_option () =
  match !me with
  | CU_idontknown -> assert false
  | CU_notconnected -> None
  | CU_user u -> Some u

let get_current_user () =
  match !me with
  | CU_user a -> a
  | CU_idontknown -> (* Should never happen *) failwith please_use_connected_fun
  | _ ->
    Ow_log.log "Not connected error in Eba_current_user";
    raise Eba_session.Not_connected

]

(* SECURITY: We can trust these functions on server side,
   because the user is set at every request from the session cookie value.
   But do not trust a user sent by the client ...
*)
let get_current_user () =
  match Eliom_reference.Volatile.get me with
  | CU_user a -> a
  | CU_idontknown -> failwith please_use_connected_fun
  | CU_notconnected -> raise Eba_session.Not_connected

let get_current_user_option () =
  let u = Eliom_reference.Volatile.get me in
  match u with
  | CU_user a -> Some a
  | CU_idontknown -> failwith please_use_connected_fun
  | CU_notconnected -> None


[%%shared
let get_current_userid () = Eba_user.userid_of_user (get_current_user ())

module Opt = struct

  let get_current_user = get_current_user_option

  let get_current_userid () =
    Eliom_lib.Option.map
      Eba_user.userid_of_user
      (get_current_user_option ())

end
 ]
[%%client
   let _ = Eba_session.get_current_userid_o := Opt.get_current_userid
]

let set_user_server userid =
  let%lwt u = Eba_user.user_of_userid userid in
  Eliom_reference.Volatile.set me (CU_user u);
  Lwt.return ()

let unset_user_server () =
  Eliom_reference.Volatile.set me CU_notconnected

let set_user_client () =
  let u = Eliom_reference.Volatile.get me in
  ignore [%client ( me := ~%u : unit)]

let unset_user_client () =
  ignore [%client ( me := CU_notconnected : unit)]




let last_activity : CalendarLib.Calendar.t option Eliom_reference.eref =
  Eliom_reference.eref
    ~persistent:"lastactivity"
    ~scope:Eliom_common.default_group_scope
    None

let () =
  Eba_session.on_request (fun userid ->
    (* I initialize current user to CU_notconnected *)
    Lwt_log.ign_debug ~section "request action";
    unset_user_server ();
    Lwt.return ());
  Eba_session.on_start_connected_process (fun userid ->
    Lwt_log.ign_debug ~section "start connected process action";
    let%lwt () = set_user_server userid in
    set_user_client ();
    Lwt.return ());
  Eba_session.on_connected_request (fun userid ->
    Lwt_log.ign_debug ~section "connected request action";
    let%lwt () = set_user_server userid in
    let now = CalendarLib.Calendar.now () in
    Eliom_reference.set last_activity (Some now));
  Eba_session.on_pre_close_session (fun () ->
    Lwt_log.ign_debug ~section "pre close session action";
    unset_user_client (); (*VVV!!! will affect only current tab!! *)
    unset_user_server (); (* ok this is a request reference *)
    Lwt.return ());
  Eba_session.on_start_process (fun () ->
    Lwt_log.ign_debug ~section "start process action";
    Lwt.return ());
  Eba_session.on_open_session (fun _ ->
    Lwt_log.ign_debug ~section "open session action";
    Lwt.return ());
  Eba_session.on_denied_request (fun _ ->
    Lwt_log.ign_debug ~section "denied request action";
    Lwt.return ())
