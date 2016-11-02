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

(* GENERAL FIXME: always use HTTPS !!!! *)

open Os_oauth2_shared

(* -------------------------------- *)
(* ---------- Exceptions ---------- *)

exception State_not_found

exception No_such_client

exception No_such_saved_token

(* ------------------------ *)
(* Request code information *)

exception No_such_request_info_code
exception No_such_userid_registered

(* Request code information *)
(* ------------------------ *)

(* ---------- Exceptions ---------- *)
(* -------------------------------- *)

(* -------------------------- *)
(* ---------- MISC ---------- *)

(* Split a string representing a list of scope value separated by space *)
let split_scope_list s = Re.split (Re.compile (Re.rep1 Re.space)) s

(* ---------- MISC ---------- *)
(* -------------------------- *)

(* ---------------------------------------- *)
(* ---------- Client credentials ---------- *)

let generate_client_credentials () =
  let client_id     = Os_oauth2_shared.generate_random_string size_client_id in
  let client_secret = Os_oauth2_shared.generate_random_string size_client_id in
  client_credentials_of_str ~client_id ~client_secret

(* ---------- Client credentials ---------- *)
(* ---------------------------------------- *)

(* ---------------------------- *)
(* ---------- Header ---------- *)

(* Check if the client id and the client secret has been set in the header while
 * requesting a token and if they are correct.
 *)
let check_authorization_header client_id header =
  try%lwt
    let%lwt client_secret =
      Os_db.OAuth2_server.client_secret_of_client_id client_id
    in
    let base64_credentials  =
      (B64.encode (client_id ^ ":" ^ client_secret))
    in
    let basic =
      Ocsigen_http_frame.Http_header.get_headers_value
        header
        Http_headers.authorization
    in
    Lwt.return (basic = "Basic " ^ base64_credentials)
  (* if the authorization value is not defined *)
  with Not_found -> Lwt.return_false

(* ---------- Header ---------- *)
(* ---------------------------- *)

(** ------------------------------------------------------------ *)
(** ---------- Functions about the authorization code ---------- *)

(** generate_authorization_code () generates an authorization code.
 * NOTE: Improve the generation by using the userid of the OAuth2 server
 * user, the client_id of OAuth2 client and the scope? *)
let generate_authorization_code () =
  Os_oauth2_shared.generate_random_string size_authorization_code

(** ---------- Functions about the authorization code ---------- *)
(** ------------------------------------------------------------ *)

(* ---------------------------- *)
(* ---------- Client ---------- *)

(* A basic OAuth2.0 client is represented by an application name, a description
 * and redirect_uri. When a client is registered, credentials and an ID is
 * assigned and becomes a {registered_client}.
 *)
type client =
{
  application_name: string;
  description: string;
  redirect_uri: string
}

let client_of_str ~application_name ~description ~redirect_uri =
{ application_name; description; redirect_uri }

let application_name_of_client c = c.application_name

let description_of_client c = c.description

let redirect_uri_of_client c = c.redirect_uri

let client_of_id id =
  try%lwt
    let%lwt (application_name, description, redirect_uri) =
      Os_db.OAuth2_server.client_of_id id
    in
    Lwt.return { application_name ; description ; redirect_uri }
  with Os_db.No_such_resource -> Lwt.fail No_such_client

(* Create a new client by generating credentials. The return value is the ID in
 * the database.
 *)
let new_client ~application_name ~description ~redirect_uri =
  let credentials = generate_client_credentials () in
  Os_db.OAuth2_server.new_client
    application_name
    description
    redirect_uri
    (client_credentials_id credentials)
    (client_credentials_secret credentials)

let remove_client_by_id id =
  Os_db.OAuth2_server.remove_client id

let remove_client_by_client_id client_id =
  let%lwt id = Os_db.OAuth2_server.id_of_client_id client_id in
  remove_client_by_id id

(* ---------- Client ---------- *)
(* ---------------------------- *)

(* --------------------------------------- *)
(* ---------- Registered client ---------- *)

type registered_client =
{
  id          : int64              ;
  client      : client             ;
  credentials : client_credentials ;
}

let id_of_registered_client t          = t.id

let client_of_registered_client t      = t.client

let credentials_of_registered_client t = t.credentials

let to_registered_client id client credentials = { id ; client ; credentials }

let registered_client_of_client_id client_id =
  try%lwt
    let%lwt (id, application_name, description, redirect_uri,
    client_id, client_secret) =
      Os_db.OAuth2_server.registered_client_of_client_id client_id
    in
    let info =
      client_of_str ~application_name ~description ~redirect_uri
    in
    let credentials =
      client_credentials_of_str ~client_id ~client_secret
    in
    Lwt.return (to_registered_client id info credentials)
  with Os_db.No_such_resource -> Lwt.fail No_such_client

let list_clients ?(min_id=Int64.of_int 0) ?(limit=Int64.of_int 10) () =
  let%lwt l = Os_db.OAuth2_server.list_clients ~min_id ~limit () in
  Lwt.return
    (List.map
      (fun (id, application_name, description,
            redirect_uri, client_id, client_secret) ->
        let info =
          client_of_str
            ~application_name
            ~description
            ~redirect_uri
        in
        let credentials =
          client_credentials_of_str
            ~client_id
            ~client_secret
        in
        to_registered_client id info credentials
      )
      l
    )

let registered_client_exists_by_client_id client_id =
  Os_db.OAuth2_server.registered_client_exists_by_client_id client_id


(* ---------- Registered client ---------- *)
(* --------------------------------------- *)

module type SCOPE =
  sig
    (* --------------------------- *)
    (* ---------- Scope ---------- *)

    (** Scope is a list of permissions *)
    type scope

    val scope_of_str :
      string ->
      scope

    val scope_to_str :
      scope ->
      string

    (** check_scope_list is used to check if the scope asked by the client is
     * allowed. You can implement simple check_scope_list by only check is all
     * element of the scope list is defined but you can also have the case where
     * two scopes can't be asked at the same time.
     *)
    val check_scope_list :
      scope list ->
      bool

    (* --------------------------- *)
    (* ---------- Scope ---------- *)
  end

module type TOKEN =
  sig
    type scope

    type saved_token

    val saved_tokens : saved_token list ref

    (* Tokens must expire after a certain amount of time. For this, a timer checks
     * all [timeout] seconds and if the token has been generated after [timeout] *
     * [number_of_timeout] seconds, we remove it.
     *)
    (** [timeout] is the number of seconds after how many we need to check if
      * saved tokens are expired.
     *)
    val timeout : int

    (** [number_of_timeout] IMPROVEME DOCUMENTATION *)
    val number_of_timeout : int

    (* ------- *)
    (* getters *)

    val id_client_of_saved_token  :
      saved_token ->
      int64

    val userid_of_saved_token     :
      saved_token ->
      int64

    val value_of_saved_token      :
      saved_token ->
      string

    val token_type_of_saved_token :
      saved_token ->
      string

    val scope_of_saved_token      :
      saved_token ->
      scope list


    val counter_of_saved_token    :
      saved_token ->
      int ref

    (* getters *)
    (* ------- *)

    (* Returns true if the token already exists *)
    val token_exists              :
      saved_token                 ->
      bool

    (* Generate a token value *)
    val generate_token_value      :
      unit                        ->
      string

    (* Generate a new token *)
    val generate_token            :
      id_client:int64             ->
      userid:int64                ->
      scope:scope list            ->
      saved_token Lwt.t

    (* Save a token *)
    val save_token                :
      saved_token                 ->
      unit

    val remove_saved_token        :
      saved_token                 ->
      unit

    val saved_token_of_id_client_and_value :
      int64                       ->
      string                      ->
      saved_token

    (* List all saved tokens *)
    val list_tokens               :
      unit                        ->
      saved_token list

    val saved_token_to_json       :
      saved_token                 ->
      Yojson.Safe.json
  end

module type SERVER =
  sig
    (* --------------------------- *)
    (* ---------- Scope ---------- *)

    (** Scope is a list of permissions *)
    type scope

    val scope_of_str :
      string ->
      scope

    val scope_to_str :
      scope ->
      string

    val scope_list_of_str_list :
      string list ->
      scope list

    val scope_list_to_str_list :
      scope list ->
      string list

    (* --------------------------- *)
    (* ---------- Scope ---------- *)

    (* --------------------------------------------- *)
    (* ---------- request code information --------- *)

    val set_userid_of_request_info_code :
      string ->
      string ->
      int64 ->
      unit

    (* ---------- request code information --------- *)
    (* --------------------------------------------- *)

    (** ------------------------------------------------------------ *)
    (** ---------- Functions about the authorization code ---------- *)

    (** send_authorization_code [state] [redirect_uri] [client_id] [scope] sends
     * an authorization code to redirect_uri
     * including the state [state]. This function can be called by
     * the authorization handler. It uses Eliom_lib.change_page.
     * It avoids to know how OAuth2 works and to implement the redirection
     * manually.
     * NOTE: The example in the RFC is a redirection but it is not mentionned
     * if is mandatory. So we use change_page.
     * FIXME: They don't return a page normally. We need to change for a Any.
     *)

    val send_authorization_code :
      string                                ->
      string                                ->
      Eliom_registration.Html.page Lwt.t

    val send_authorization_code_error :
      ?error_description:string option      ->
      ?error_uri:string option              ->
      error_authorization_code_type         ->
      string                                ->
      Ocsigen_lib.Url.t                     ->
      Eliom_registration.Html.page Lwt.t

    val rpc_resource_owner_authorize  :
      (
        Deriving_Json.Json_string.a *
        Deriving_Json.Json_string.a,
        Eliom_registration.Html.page
      )
      Eliom_client.server_function

    val rpc_resource_owner_decline    :
      (
        Deriving_Json.Json_string.a * Deriving_Json.Json_string.a,
        Eliom_registration.Html.page
      )
      Eliom_client.server_function

    (** ---------- Functions about the authorization code ---------- *)
    (** ------------------------------------------------------------ *)

    (** ------------------------------------------ *)
    (** ---------- Function about token ---------- *)

    type saved_token

    val id_client_of_saved_token  : saved_token -> int64
    val userid_of_saved_token     : saved_token -> int64
    val value_of_saved_token      : saved_token -> string
    val token_type_of_saved_token : saved_token -> string
    val scope_of_saved_token      : saved_token -> scope list

    val token_exists              :
      saved_token           ->
      bool

    val save_token                :
      saved_token           ->
      unit

    val remove_saved_token        :
      saved_token           ->
      unit

    val saved_token_of_id_client_and_value :
      int64                       ->
      string                      ->
      saved_token

    val list_tokens               :
      unit                  ->
      saved_token list

    (** ---------- Function about token ---------- *)
    (** ------------------------------------------ *)


    (** ---------- URL registration ---------- *)
    (** -------------------------------------- *)

    (** When registering, we need to have several get parameters so we need to
     * force the developer to have these GET parameter. We define a type for the
     * token handler and the authorization handler.
     * because they have different GET parameters.
     *
     * There are not abstract because we need to know the type. And it's also
     * known due to RFC.
     **)

    (** ------------------------------------------------ *)
    (** ---------- Authorization registration ---------- *)

    (* --------------------- *)
    (* authorization service *)

    (** Type of pre-defined service for authorization service. It's a GET
     * service
     *)
    (* NOTE: need to improve this type! It's so ugly *)
    type authorization_service =
      (string * (string * (string * (string * string))),
      unit,
      Eliom_service.get,
      Eliom_service.att,
      Eliom_service.non_co,
      Eliom_service.non_ext,
      Eliom_service.reg, [ `WithoutSuffix ],
      [ `One of string ]
      Eliom_parameter.param_name *
      ([ `One of string ]
       Eliom_parameter.param_name *
       ([ `One of string ]
        Eliom_parameter.param_name *
        ([ `One of string ]
         Eliom_parameter.param_name *
         [ `One of string ]
         Eliom_parameter.param_name))),
      unit, Eliom_service.non_ocaml)
      Eliom_service.t

    (** authorization_service [path] returns a service for the authorization URL.
     * You can use it with Your_app_name.App.register with
     * {!authorization_handler} *)
    val authorization_service :
      Eliom_lib.Url.path ->
      authorization_service

    (* authorization service *)
    (* --------------------- *)

    (* --------------------- *)
    (* authorization handler *)

    type authorization_handler  =
      state:string          ->
      client_id:string      ->
      redirect_uri:string   ->
      scope:scope list      ->
      Eliom_registration.Html.page Lwt.t (* Return value of the handler *)

    (** authorize_handler [handler] returns a handler for the authorization URL.
     * You can use it with Your_app_name.App.register with
     * {!authorization_service}
     *)
    val authorization_handler :
      authorization_handler ->
      (
        (string * (string * (string * (string * string))))  ->
        unit                                                ->
        Eliom_registration.Html.page Lwt.t
      )

    (* authorization handler *)
    (* --------------------- *)

    (** ---------- Authorization registration ---------- *)
    (** ------------------------------------------------ *)

    (** ---------------------------------------- *)
    (** ---------- Token registration ---------- *)

    (* ------------- *)
    (* token service *)

    (** Type of pre-defined service for token service. It's a POST service. *)
    (* NOTE: need to improve this type! It's so ugly *)
    type token_service =
      (unit,
      string * (string * (string * (string * string))),
      Eliom_service.post,
      Eliom_service.att,
      Eliom_service.non_co,
      Eliom_service.non_ext,
      Eliom_service.reg,
      [ `WithoutSuffix ],
      unit,
      [ `One of string ] Eliom_parameter.param_name *
      ([ `One of string ] Eliom_parameter.param_name *
        ([ `One of string ] Eliom_parameter.param_name *
          ([ `One of string ] Eliom_parameter.param_name *
            [ `One of string ] Eliom_parameter.param_name))),
      Eliom_registration.String.return)
      Eliom_service.t

    (** token_service [path] returns a service for the access token URL.
     * You can use it with Your_app_name.App.register with
     * {!token_handler}
     *)
    val token_service :
      Eliom_lib.Url.path ->
      token_service

    (* token service *)
    (* ------------- *)

    (* ------------- *)
    (* token handler *)

    (** token_handler returns a handler for the access token URL.
     * You can use it with Your_app_name.App.register with
     * {!token_service}
     *)
    val token_handler :
      (
        unit                                                  ->
        (string * (string * (string * (string * string))))    ->
        Eliom_registration.String.result Lwt.t
      )

    (* token handler *)
    (* ------------- *)

    (** ---------- Token registration ---------- *)
    (** ---------------------------------------- *)

    (** ---------- URL registration ---------- *)
    (** -------------------------------------- *)

  end

module MakeServer
  (Scope : SCOPE)
  (Token : (TOKEN with type scope = Scope.scope)) : (SERVER with
    type scope = Scope.scope and
    type saved_token = Token.saved_token) =
  struct
    (* --------------------------- *)
    (* ---------- Scope ---------- *)

    (** Scope is a list of permissions *)
    type scope = Scope.scope

    let scope_of_str = Scope.scope_of_str

    let scope_to_str = Scope.scope_to_str

    let scope_list_of_str_list l = List.map scope_of_str l

    let scope_list_to_str_list l = List.map scope_to_str l

    let check_scope_list = Scope.check_scope_list

    (* --------------------------- *)
    (* ---------- Scope ---------- *)

    (* ------------------------------------------------ *)
    (* --------------- Not in signature --------------- *)

    (* ----------------------------------------- *)
    (* ---------- request information ---------- *)

    let number_of_timeout_request_info = 10
    let timeout_request_info           = 60

    type request_info =
    {
      userid        : int64             ;
      redirect_uri  : Ocsigen_lib.Url.t ;
      client_id     : string            ;
      code          : string            ;
      state         : string            ;
      scope         : scope list        ;
      counter       : int ref           ;
    }

    let userid_of_request_info c        = c.userid
    let redirect_uri_of_request_info c  = c.redirect_uri
    let client_id_of_request_info c     = c.client_id
    let code_of_request_info c          = c.code
    let state_of_request_info c         = c.state
    let scope_of_request_info c         = c.scope

    let request_info : request_info list ref = ref []

    let _ =
      update_list_timer
        timeout_request_info
        (fun x -> let c = x.counter in !c >= number_of_timeout_request_info)
        (fun x -> incr x.counter)
        request_info

    let add_request_info userid redirect_uri client_id code state scope =
      let new_state =
        {
          userid ; redirect_uri ; client_id ;
          code ; state ; scope ; counter = ref 0
        }
      in
      request_info := (new_state :: (! request_info))

    (** remove_request_info [state] removes the request_info which has [state]
     * as state.
     *)
    let remove_request_info_by_state_and_client_id state client_id =
      remove_from_list
        (fun x -> x.state = state && x.client_id = client_id)
        (! request_info)

    (** Get the request info type with [state]. Raise State_not_found if no
     * request has been done with [state]
     *)
    let request_info_of_state state =
      let rec request_info_of_state_intern l = match l with
      | [] -> raise State_not_found
      | head::tail ->
          if head.state = state then head
          else request_info_of_state_intern tail
      in
      request_info_of_state_intern (! request_info)

    (** Debug function to print the request information list *)
    let print_request_info_state_list () =
      let states = ! request_info in
      if List.length states = 0 then
        print_endline "No registered states"
      else
        List.iter
          (fun r ->
            print_endline ("State: " ^ (state_of_request_info r)) ;
            print_endline
              ("userid: " ^ (Int64.to_string (userid_of_request_info r)));
            print_endline ("redirect_uri: " ^ (redirect_uri_of_request_info r));
            print_endline ("code: " ^ (code_of_request_info r));
            print_endline
              ("client_id: " ^ (client_id_of_request_info r))
          )
          states

    (** check_state_already_used [client_id] [state] returns true if the state
     * [state] is already used for the client [client_id]. Else returns false.
     * As we use state to get the request information between authorization and
     * token endpoint, we need to be sure it's unique.
     *)

    let check_state_already_used client_id state =
      let rec check_state_already_used_intern l =
        match l with
        | [] -> false
        | head::tail ->
            if (head.state = state && head.client_id = client_id) then true
            else check_state_already_used_intern tail
      in
      check_state_already_used_intern (! request_info)

    (* ---------- request information ---------- *)
    (* ------------------------------------------ *)

    (* --------------------------------------------- *)
    (* ---------- request code information --------- *)

    type request_info_code =
    {
      state        : string            ;
      client_id    : string            ;
      userid       : int64 option ref  ; (* use option because need a way to
      distinct if it is set or not. Negative value is not the best way *)
      redirect_uri : Ocsigen_lib.Url.t ;
      scope        : scope list
    }

    let new_request_info_code ?(userid=None) state client_id redirect_uri scope
    =
      { state ; client_id ; userid = ref userid ; redirect_uri ; scope }

    let request_info_code : request_info_code list ref = ref []

    let add_request_info_code request =
      request_info_code := (request :: (!request_info_code))

    let request_info_code_of_state_and_client_id state client_id =
      try
        List.find
          (fun x -> x.state = state && x.client_id = client_id)
          (!request_info_code)
      with Not_found -> raise No_such_request_info_code

    let set_userid_of_request_info_code client_id state userid =
      let request = request_info_code_of_state_and_client_id state client_id in
      request.userid := Some userid

    let remove_request_info_code_by_client_id_and_state client_id state =
      remove_from_list
        (fun x -> x.client_id = client_id && x.state = state)
        (! request_info_code)

    (* ---------- request code information --------- *)
    (* --------------------------------------------- *)

    (* --------------- Not in signature --------------- *)
    (* ------------------------------------------------ *)


    (** ------------------------------------------------------------ *)
    (** ---------- Functions about the authorization code ---------- *)

    (* Send the authorization code and redirect the user-agent to
     * [redirect_uri]
     * TODO: Use redirection and not change_page.
     * TODO: if there's already a token for this client_id and this userid, send
     * the token and not the code.
     * NOTE: As the client_id and state are sent as GET parameters (so visible
     * by the user agent), we can use it client-side without lack of security.
     * If these informations are changed client-side, it will raise an error
     * No_such_request_info_code and it will be caught in
    * [authorization_handler] which will call send_authorization_code_error.
     *)
    let send_authorization_code state client_id =
      let request_info_code_tmp =
        request_info_code_of_state_and_client_id state client_id
      in
      let (prefix, path) =
        Os_oauth2_shared.prefix_and_path_of_url request_info_code_tmp.redirect_uri
      in
      let () = match !(request_info_code_tmp.userid) with
      | None -> raise No_such_userid_registered
      | Some userid ->
      (
        let code = generate_authorization_code () in
        let service_url = Eliom_service.extern
          ~prefix
          ~path
          ~meth:param_authorization_code_response
          ()
        in
        add_request_info
          userid
          request_info_code_tmp.redirect_uri
          client_id
          code
          state
          request_info_code_tmp.scope;
        ignore(remove_request_info_code_by_client_id_and_state client_id state);
        ignore([%client (
          let service_url = ~%service_url in
          ignore (Eliom_client.change_page
            ~service:service_url
            (~%code, ~%state)
            ())
          : unit
        )])
      )
      in
      Lwt.return (
        Eliom_tools.D.html
          ~title:"Authorization code: temporarily page"
          Eliom_content.Html.D.(body []);
      )

    (* Send an error code and redirect the user-agent to [redirect_uri] *)
    let send_authorization_code_error
      ?(error_description=None)
      ?(error_uri=None)
      error
      state
      redirect_uri
      =
      let (prefix, path) =
        Os_oauth2_shared.prefix_and_path_of_url redirect_uri
      in
      let service_url = Eliom_service.extern
        ~prefix
        ~path
        ~meth:param_authorization_code_response_error
        ()
      in
      let error_str = error_authorization_code_type_to_str error in
      (* It is not mentionned in the RFC if we need to send an error code in the
       * redirection. So a simple change_page does the job.
       *)
      ignore ([%client (
        let service_url = ~%service_url in
        Eliom_client.change_page
          ~service:service_url
          (~%error_str, (~%error_description, (~%error_uri, ~%state)))
          ()
        : unit Lwt.t
      )]);
      Lwt.return (
        Eliom_tools.D.html
          ~title:"Authorization code error: temporarily page"
          Eliom_content.Html.D.(body []);
      )

    (* When resource owner authorizes the client. Normally, you don't need to use
     * this function: {!rpc_resource_owner_authorize} is enough *)
    let resource_owner_authorize (state, client_id) =
      send_authorization_code state client_id

    (* RPC to use. Must be used client side when the resource owner authorizes.
     *)
    let rpc_resource_owner_authorize =
      Eliom_client.server_function
        [%derive.json: (string * string)]
        resource_owner_authorize

    (* When resource owner declines the client. Normally, you don't need to use
     * this function: {!rpc_resource_owner_decline} is enough.
     *
     * State and redirect_uri are visible in the URL because they are sent as
     * GET parameters. There's no lack of security if they are changed
     * client-side
     *)
    let resource_owner_decline (state, redirect_uri) =
      send_authorization_code_error
        ~error_description:(Some ("The resource owner doesn't authorize you to
        access its data"))
        Auth_access_denied
        state
        redirect_uri

    (* RPC to use. Must be used client side when the resource owner declines. *)
    let rpc_resource_owner_decline =
      Eliom_client.server_function
        [%derive.json: string * string]
        resource_owner_decline

    (** ---------- Functions about the authorization code ---------- *)
    (** ------------------------------------------------------------ *)

    (** -------------------------------------- *)
    (** ---------- URL registration ---------- *)

    (** ------------------------------------------------ *)
    (** ---------- Authorization registration ---------- *)

    (* --------------------- *)
    (* Authorization service *)

    (** Type of pre-defined service for authorization service. It's a GET
     * service
     *)
    type authorization_service =
      (string * (string * (string * (string * string))),
      unit,
      Eliom_service.get,
      Eliom_service.att,
      Eliom_service.non_co,
      Eliom_service.non_ext,
      Eliom_service.reg, [ `WithoutSuffix ],
      [ `One of string ]
      Eliom_parameter.param_name *
      ([ `One of string ]
       Eliom_parameter.param_name *
       ([ `One of string ]
        Eliom_parameter.param_name *
        ([ `One of string ]
         Eliom_parameter.param_name *
         [ `One of string ]
         Eliom_parameter.param_name))),
      unit, Eliom_service.non_ocaml)
      Eliom_service.t

    let authorization_service path =
      Eliom_service.create
        ~path:(Eliom_service.Path path)
        ~meth:param_authorization_code
        ~https:true
        ()

    (* Authorization service *)
    (* --------------------- *)

    (* --------------------- *)
    (* Authorization handler *)

    type authorization_handler  =
      state:string          ->
      client_id:string      ->
      redirect_uri:string   ->
      scope:scope list      ->
      Eliom_registration.Html.page Lwt.t (* Return value of the handler *)

    (** ---------- Authorization registration ---------- *)
    (** ------------------------------------------------ *)

    (* Performs check on client_id, scope and response_type before sent state,
     * client_id, redirect_uri and scope to the handler
     *)
    let authorization_handler handler =
      fun (response_type, (client_id, (redirect_uri, (scope, state)))) () ->
        try%lwt
          let scope_list = (scope_list_of_str_list (split_scope_list scope)) in
          (* IMPROVEME: authenticates the client. http_header must be used. For
           * the moment, we only check if the client exists because we don't how
           * to send HTTP headers value when calling a service.
           * NOTE: it's OK for the moment because it is checked in the token
           * request.
           *)
          let%lwt authorized        =
            registered_client_exists_by_client_id client_id
          in
          let%lwt registered_client =
            registered_client_of_client_id client_id
          in
          let redirect_uri_bdd      =
            redirect_uri_of_client
              (client_of_registered_client registered_client)
          in
          let state_already_used    =
            check_state_already_used client_id state
          in
          (*
          let http_header     = Eliom_request_info.get_http_header ()         in
          let%lwt authorized  =
            check_authorization_header client_id http_header
          in
          *)
          if (response_type <> "code") then
            send_authorization_code_error
              ~error_description:(Some (response_type ^ " is not supported."))
              Auth_invalid_request
              state
              redirect_uri
          else if state_already_used then
            send_authorization_code_error
              ~error_description:
                (Some ("State already used. It is recommended to generate \
                random state with minimum 30 characters"))
              Auth_invalid_request
              state
              redirect_uri
          else if not authorized then
            send_authorization_code_error
              ~error_description:
                (Some ("You are an unauthorized client. Please register before \
                or check your credentials."))
              Auth_unauthorized_client
              state
              redirect_uri
          else if not (check_scope_list scope_list) then
            send_authorization_code_error
              ~error_description:
                (Some ("Some values in scope list are not available or you \
                forgot some mandatory scope value."))
              Auth_invalid_scope
              state
              redirect_uri
          else if redirect_uri <> redirect_uri_bdd then
          (
            send_authorization_code_error
              ~error_description:
                (Some ("Check the value of redirect_uri."))
              Auth_invalid_request
              state
              redirect_uri
          )
          else
          (
            add_request_info_code
              (new_request_info_code
                state
                client_id
                redirect_uri
                scope_list
              );
            handler
              ~state
              ~client_id
              ~redirect_uri
              ~scope:scope_list
          )
        with
        (* Comes from registered_client_of_client_id. It means the client
         * doesn't exist because the function can't get any information about
         * the client. *)
        | No_such_client ->
            send_authorization_code_error
              ~error_description:
                (Some ("You are an unauthorized client. Please register before \
                or check your credentials."))
              Auth_unauthorized_client
              state
              redirect_uri
        (* Comes from send_authorization_code while trying to get the
         * request code information. It means the state or the client_id has
         * been changed client-side ==> Maybe someone try to redirect the code
         * to another URI.
         *)
        | No_such_request_info_code ->
            send_authorization_code_error
              ~error_description:
                (Some ("Error while sending the code. Please check if you \
                changed the client_id or the state."))
              Auth_invalid_request
              state
              redirect_uri
        (* Comes from send_authorization_code while trying to get the userid of
         * the user who authorized the OAuth2.0 client. It means no userid has
         * been set.
         *)
        | No_such_userid_registered ->
            send_authorization_code_error
              ~error_description:
                (Some ("Error while sending the code. No user has authorized."))
              Auth_invalid_request
              state
              redirect_uri

    (* Authorization handler *)
    (* --------------------- *)

    (** ---------- Authorization registration ---------- *)
    (** ------------------------------------------------ *)

    (** ---------- URL registration ---------- *)
    (** -------------------------------------- *)

    (** ------------------------------------------ *)
    (** ---------- Function about token ---------- *)

    type saved_token              = Token.saved_token

    let id_client_of_saved_token  = Token.id_client_of_saved_token
    let userid_of_saved_token     = Token.userid_of_saved_token
    let value_of_saved_token      = Token.value_of_saved_token
    let token_type_of_saved_token = Token.token_type_of_saved_token
    let scope_of_saved_token      = Token.scope_of_saved_token

    let generate_token            = Token.generate_token

    let save_token                = Token.save_token

    let remove_saved_token        = Token.remove_saved_token

    let saved_token_of_id_client_and_value =
      Token.saved_token_of_id_client_and_value

    let list_tokens               = Token.list_tokens

    let token_exists              = Token.token_exists

    let saved_token_to_json       = Token.saved_token_to_json

    let send_token_error
      ?(error_description=None) ?(error_uri=None) error =
      let json_error = match (error_description, error_uri) with
        | (None, None) ->
            `Assoc [ ("error", `String (error_token_type_to_str error)) ]
        | (None, Some x) ->
          `Assoc
          [
            ("error", `String (error_token_type_to_str error)) ;
            ("error_uri", `String x)
          ]
        | (Some x, None) ->
          `Assoc
          [
            ("error", `String (error_token_type_to_str error)) ;
            ("error_description", `String x)
          ]
        | (Some x, Some y) ->
          `Assoc
          [
            ("error", `String (error_token_type_to_str error)) ;
            ("error_description", `String x) ;
            ("error_uri", `String y)
          ]
      in
      let headers =
        Http_headers.add
          Http_headers.cache_control
          "no-store"
          (Http_headers.add
            Http_headers.pragma
            "no-cache"
            Http_headers.empty
          )
      in
      (* NOTE: RFC page 45 *)
      let code = match error with
      | Token_invalid_client -> 401
      | _ -> 400
      in

      Eliom_registration.String.send
        ~code
        ~content_type:"application/json;charset=UTF-8"
        ~headers
        (
          Yojson.Safe.to_string json_error,
          "application/json;charset=UTF-8"
        )

        (** ---------- Function about token ---------- *)
    (** ------------------------------------------ *)

    (** ---------------------------------------- *)
    (** ---------- Token registration ---------- *)

    (* ------------- *)
    (* token service *)

    type token_service =
      (unit,
      string * (string * (string * (string * string))),
      Eliom_service.post,
      Eliom_service.att,
      Eliom_service.non_co,
      Eliom_service.non_ext,
      Eliom_service.reg,
      [ `WithoutSuffix ],
      unit,
      [ `One of string ] Eliom_parameter.param_name *
      ([ `One of string ] Eliom_parameter.param_name *
        ([ `One of string ] Eliom_parameter.param_name *
          ([ `One of string ] Eliom_parameter.param_name *
            [ `One of string ] Eliom_parameter.param_name))),
      Eliom_registration.String.return)
      Eliom_service.t

    let token_service path =
      update_list_timer
        Token.timeout
        (fun x -> let c = Token.counter_of_saved_token x in !c >= Token.number_of_timeout)
        (fun x -> let c = Token.counter_of_saved_token x in incr c)
        Token.saved_tokens
        ();
      Eliom_service.create
        ~path:(Eliom_service.Path path)
        ~meth:param_access_token
        ~https:true
        ()

    (* token service *)
    (* ------------- *)

    (* ------------- *)
    (* token handler *)

    (* NOTE: the state is not mandatory but it is used to get information about
     * the request. Not in RFC!!
     *)
    let token_handler =
      fun () (grant_type, (code, (redirect_uri, (state, client_id)))) ->
        try%lwt
          let http_header         = Eliom_request_info.get_http_header ()     in
          (* Fetch information about the request *)
          let request_info        = request_info_of_state state               in
          let redirect_uri_state  = redirect_uri_of_request_info request_info in
          let code_state          = code_of_request_info request_info         in
          let userid              = userid_of_request_info request_info       in
          let scope               = scope_of_request_info request_info        in
          (* Check if the client is well authenticated *)
          let%lwt authorized      =
            check_authorization_header client_id http_header
          in
          if not authorized then
            (* Need to add HTTP 401 (Unauthorized) response, see page 45 *)
            send_token_error
              ~error_description:
                (Some "Client authentication failed. Please check your client \
                credentials and if you mentionned it in the request header.")
              Token_invalid_client
          else if grant_type <> "authorization_code" then
            send_token_error
              ~error_description:
                (Some "This authorization grant type is not supported.")
              Token_unsupported_grant_type
          else if code <> code_state then
            send_token_error
              ~error_description:
                (Some "Wrong code")
              Token_invalid_grant
          else if redirect_uri <> redirect_uri_state then
            send_token_error
              ~error_description:
                (Some "Wrong redirect_uri")
              Token_invalid_grant
          else
          (
            let%lwt id_client =
              Os_db.OAuth2_server.id_of_client_id client_id
            in
            let%lwt token =
              generate_token
                ~id_client
                ~userid
                ~scope
            in
            let json = saved_token_to_json token in
            let headers =
              Http_headers.add
                Http_headers.cache_control
                "no-store"
                (Http_headers.add
                  Http_headers.pragma
                  "no-cache"
                  Http_headers.empty
                )
            in
            ignore (remove_request_info_by_state_and_client_id state client_id);
            save_token token;
            Eliom_registration.String.send
              ~code:200
              ~content_type:"application/json;charset=UTF-8"
              ~headers
              (Yojson.Safe.to_string json,
              "application/json;charset=UTF-8")
          )
        with
        (* comes from request_info_of_state if no state found *)
        | State_not_found ->
            send_token_error
              ~error_description:
                (Some "Wrong state")
              Token_invalid_request
        | Os_db.No_such_resource ->
            send_token_error
              ~error_description:
                (Some "Client authentication failed.")
              Token_invalid_client

    (* token handler *)
    (* ------------- *)

    (** ---------- Token registration ---------- *)
    (** ---------------------------------------- *)
  end

module Basic_scope = struct
  (* --------------------------- *)
  (* ---------- Scope ---------- *)

  type scope = OAuth | Firstname | Lastname | Email | Unknown

  let scope_to_str = function
    | OAuth       -> "oauth"
    | Firstname   -> "firstname"
    | Lastname    -> "lastname"
    | Email       -> "email"
    | Unknown     -> ""

  let scope_of_str = function
    | "oauth"     -> OAuth
    | "firstname" -> Firstname
    | "lastname"  -> Lastname
    | "email"     -> Email
    | _           -> Unknown

  (** check_scope_list scope_list returns true if every element in
  * [scope_list] is a available scope value.
  * If the list contains only OAuth or if the list doesn't contain OAuth
  * (mandatory scope in RFC), returns false.
  * If an unknown scope value is in list (represented by Unknown value), returns
  * false.
  *)
  let check_scope_list scope_list =
    if List.length scope_list = 0
    then false
    else if List.length scope_list = 1 && List.hd scope_list = OAuth
    then false
    else if not (List.mem OAuth scope_list)
    then false
    else
      List.for_all
        (fun x -> match x with
          | Unknown -> false
          | _ -> true
        )
        scope_list

  (* ---------- Scope ---------- *)
  (* --------------------------- *)
end

module MakeBasicToken (Scope : SCOPE) : (TOKEN with type scope = Scope.scope) =
  struct
    (** ------------------------------------------ *)
    (** ---------- Function about token ---------- *)
    type scope = Scope.scope

    let timeout               = 10

    let number_of_timeout     = 1

    type saved_token =
    {
      id_client  : int64 ;
      userid     : int64 ;
      value      : string ;
      token_type : string ;
      counter    : int ref ;
      scope      : scope list
    }

    let saved_tokens : saved_token list ref = ref []

    (* ------- *)
    (* getters *)

    let id_client_of_saved_token t  = t.id_client

    let userid_of_saved_token t     = t.userid

    let value_of_saved_token t      = t.value

    let token_type_of_saved_token t = t.token_type

    let scope_of_saved_token t      = t.scope

    let counter_of_saved_token t    = t.counter

    (* getters *)
    (* ------- *)

    (** token_exists_by_id_client_and_value [id_client] [value] returns true if
      * there exists a saved token with [id_client] and [value].
      *)
    let token_exists_by_id_client_and_value id_client value =
      List.exists
        (fun x -> x.id_client = id_client && x.value = value)
        (! saved_tokens)

    (** token_exists [saved_token] returns true if [saved_token] exists
      *)
    let token_exists saved_token =
      let id_client   = id_client_of_saved_token saved_token  in
      let value       = value_of_saved_token saved_token      in
      token_exists_by_id_client_and_value id_client value

    let generate_token_value () =
      Os_oauth2_shared.generate_random_string size_token

    let generate_token ~id_client ~userid ~scope =
      let rec generate_token_if_doesnt_exists id_client =
        let value = generate_token_value () in
        if token_exists_by_id_client_and_value id_client value
        then generate_token_if_doesnt_exists id_client
        else value
      in
      let value = generate_token_if_doesnt_exists id_client in
      Lwt.return
        {
          id_client ; userid ; value ; token_type = "bearer" ;
          scope ; counter = ref 0
        }

    let save_token token =
      saved_tokens := (token :: (! saved_tokens))

    let remove_saved_token saved_token =
      let value       = value_of_saved_token saved_token      in
      let id_client   = id_client_of_saved_token saved_token  in
      saved_tokens :=
      (
        remove_from_list
          (fun x -> x.value = value && x.id_client = id_client)
          (! saved_tokens)
      )

    let saved_token_of_id_client_and_value id_client value =
      let tokens = (! saved_tokens) in
      let rec locale = function
      | [] -> raise No_such_saved_token
      | head::tail ->
          if head.id_client = id_client && head.value = value
          then head
          else locale tail
      in
      locale tokens

    (* List all saved tokens *)
    (* IMPROVEME: list tokens by client OAuth2 id *)
    let list_tokens () =
      (! saved_tokens)

    let saved_token_to_json saved_token =
      `Assoc
      [
        ("token_type", `String "bearer") ;
        ("token", `String (value_of_saved_token saved_token)) ;
        (* FIXME: See fixme for saved_token value. *)
        (* ("expires_in", `Int 3600) ; *)
        (* ("refresh_token", `String refresh_token) ;*)
      ]

    (** ---------- Function about token ---------- *)
    (** ------------------------------------------ *)
  end

module Basic_token = MakeBasicToken (Basic_scope)

module Basic = MakeServer (Basic_scope) (Basic_token)
