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

(** OpenID Connect client with default scopes ({!Basic_scope}), ID Tokens
    ({!Basic_ID_Token}) and client implementation ({!Basic}).
 *)

(** {1 Exceptions} *)

(** Exception raised when the JSON received from the OpenID Connect server is
    not well formated or if there is missing fields.
 *)
exception Bad_JSON_response

(** Exception raised when the given token doesn't exist. *)
exception No_such_saved_token

(** {2 Token representation. } *)

(** Interface for ID Token used by the OpenID Connect server. *)

module type IDTOKEN = sig
  (** Represent a saved token. The type is abstract to let the choice of the
      implementation.
      In addition to {!Os_oauth2_client.TOKEN.saved_token}, a token must contain
      at least:
      - the token type (for example ["bearer"]).
      - the scopes list (of type {!scope}). Used to know which data the data
      service must send.

      - the ID token as a JSON Web Token (JWT).
   *)
  type saved_token

  (** Represents the list of all saved tokens. *)
  val saved_tokens : saved_token list ref

  (** Tokens must expire after a certain amount of time. For this reason, a
      timer {!Os_oauth2_shared.update_list_timer} checks all {!cycle_duration}
      seconds if the token has been generated after {!cycle_duration} *
      {!number_of_cycle} seconds. If it's the case, the token is removed.
   *)
  (** The duration of a cycle. *)
  val cycle_duration : int

  (** [number_of_cycle] the number of cycle. *)
  val number_of_cycle : int

  (** Return the OpenID Connect server ID which delivered the token. *)
  val id_server_of_saved_token :
    saved_token ->
    Os_types.OAuth2.Server.id

  (** Return the token value. *)
  val value_of_saved_token                 :
    saved_token ->
    string

  (** Return the token type (for example ["bearer"]. *)
  val token_type_of_saved_token            :
    saved_token ->
    string

  (** Return the ID token as a JWT. *)
  val id_token_of_saved_token              :
    saved_token ->
    Jwt.t

  (** Return the number of remaining cycles. *)
  val counter_of_saved_token               :
    saved_token  ->
    int ref

  (** [parse_json_token id_server token] parse the JSON data returned by the
      token server (which has the ID [id_server] in the database) and returns
      the corresponding {!save_token} OCaml type. The
      Must raise {!Bad_JSON_response} if all needed information are not given.
      Unrecognized JSON attributes must be ignored.
   *)
  val parse_json_token    :
    Os_types.OAuth2.Server.id ->
    Yojson.Basic.json         ->
    saved_token

  (** [saved_token_of_id_server_and_value id_server value] returns the
      saved_token delivered by the server with ID [id_server] and with value
     [value].
     Raise an exception {!No_such_saved_token} if no token has been delivered by
     [id_server] with value [value].

     It implies OpenID Connect servers delivers unique token values, which is
     logical for security.
   *)
  val saved_token_of_id_server_and_value   :
    Os_types.OAuth2.Server.id ->
    string                    ->
    saved_token

  (** [save_token token] saves a new token. *)
  val save_token          :
    saved_token         ->
    unit

  (** Return all saved tokens as a list. *)
  val list_tokens         :
    unit                ->
    saved_token list

  (** [remove_saved_token token] removes [token] (used for example when [token]
      is expired.
   *)
  val remove_saved_token  :
    saved_token         ->
    unit
  end

(** {3 Basic modules for scopes, tokens and client. } *)

(** Basic scope for OpenID Connect. *)

module Basic_scope : sig
  (** Available scopes. When doing a request, [OpenID] is automatically
      set.
   *)
  type scope =
    | OpenID (** Mandatory in each requests (due to RFC).*)
    | Firstname (** Get access to the first name *)
    | Lastname (** Get access to the last name *)
    | Email (** Get access to the email *)
    | Unknown (** Used when an unknown scope is given. *)

  (** Default scopes is set to {{!scope}OpenID} (due to RFC). *)
  val default_scopes : scope list

  (** Get a string representation of the scope. {{!scope}Unknown} string
      representation is the empty string.
   *)
  val scope_to_str : scope -> string

  (** Converts a string scope to {!scope} type. *)
  val scope_of_str : string -> scope
end

(** Basic ID token implementation. *)

module Basic_ID_token : IDTOKEN

(** Basic OpenID Connect client implementation using {!Basic_scope} and
    {!Basic_ID_token}.
 *)
module Basic : (Os_oauth2_client.CLIENT with
  type scope = Basic_scope.scope and
  type saved_token = Basic_ID_token.saved_token)
