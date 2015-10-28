exception Already_exists of int64
exception No_such_user

(** Has user set its password? *)
val password_set : int64 -> bool Lwt.t

{shared{
  (** The type which represents a user. *)
type t = {
    userid : int64;
    fn : string;
    ln : string;
    avatar : string option;
  } deriving (Json)

val userid_of_user : t -> int64
val firstname_of_user : t -> string
val lastname_of_user : t -> string
val avatar_of_user : t -> string option
val avatar_uri_of_avatar : string -> Eliom_content.Xml.uri
val avatar_uri_of_user : t -> Eliom_content.Xml.uri option

(** Retrieve the full name of user. *)
val fullname_of_user : t -> string

(** Returns true if the firstname and the lastname of [t] has not
  * been completed yet. *)
val is_complete : t -> bool
}}

val emails_of_user : t -> string Lwt.t


val add_activationkey : act_key:string -> string -> unit Lwt.t
val verify_password : email:string -> password:string -> int64 Lwt.t

(** returns user information.
    Results are cached in memory during page generation. *)
val user_of_userid : int64 -> t Lwt.t

val userid_of_activationkey : string -> int64 Lwt.t
(** Retrieve an userid from an activation key. May raise [No_such_resource] if
    the activation key is not found (or outdated). *)

val userid_of_email : string -> int64 Lwt.t

(** Retrieve e-mails from user id. *)
val emails_of_userid : int64 -> string list Lwt.t

(** Retrieve (email, is_primary, is_activated) list from user id. *)
val emails_and_params_of_userid: int64 -> (string * bool * bool) list Lwt.t

(** Retrieve one of the e-mails of a user. *)
val email_of_user : t -> string Lwt.t

(** Retrieve one of the e-mails from user id. *)
val email_of_userid : int64 -> string Lwt.t

(** Retrieve e-mails of a user. *)
val emails_of_user : t -> string list Lwt.t

(** Add additional email to user. *)
val add_email_to_user: int64 -> string -> unit Lwt.t

(** Get users who match the [pattern] (useful for completion) *)
val get_users : ?pattern:string -> unit -> t list Lwt.t

(** Create a new user *)
val create :
  ?password:string -> ?avatar:string ->
  firstname:string -> lastname:string -> string -> t Lwt.t

(** Update the informations of a user. *)
val update :
  ?password:string -> ?avatar:string ->
  firstname:string -> lastname:string -> int64 -> unit Lwt.t

(** Another version of [update] using a type [t] instead of labels. *)
val update' : ?password:string -> t -> unit Lwt.t

(** Update the password only *)
val update_password : string -> int64 -> unit Lwt.t

(** Update the avatar only *)
val update_avatar : string -> int64 -> unit Lwt.t

(** Check wether or not a user exists *)
val is_registered : string -> bool Lwt.t

(** Check wether or not a user exists. *)
val is_preregistered : string -> bool Lwt.t

(** Add an email into the preregister collections. *)
val add_preregister : string -> unit Lwt.t

(** Rempve an email from the preregister collections. *)
val remove_preregister : string -> unit Lwt.t

(** Get [limit] (default: 10) emails from the preregister collections. *)
val all : ?limit:int64 -> unit -> string list Lwt.t

(** By default, passwords are encrypted using Bcrypt.
    You can customize this by calling this function
    with a pair of function (crypt and check password).
    The first parameter of the second function is the user id
    (in case you need it).
    Then it takes as second parameter the password given
    by user, and as third parameter the hash found in database.
*)
val set_pwd_crypt_fun : (string -> string) *
                        (int64 -> string -> string -> bool) -> unit
