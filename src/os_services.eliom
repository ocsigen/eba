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

(** This module defines services which are mostly used for actions like the
    signup process, to update user data, when a user forgot his password, etc.
    Some of them are used in forms defined in Os_view.
    Predefined handlers for each service are defined in the module
    Os_handlers. *)

[%%server
  open Eliom_parameter
]

(** The main service. *)
let%server main_service =
  Eliom_service.create
    ~path:(Eliom_service.Path [])
    ~meth:(Eliom_service.Get Eliom_parameter.unit)
    ()

(** A POST service to preregister a user. By default, an email is
    enough. *)
let%server preregister_service =
  Eliom_service.create
    ~name:"preregister_service"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit,
          Eliom_parameter.string "email"))
    ()

(** A POST service when the user forgot his password.
    See {!Os_handlers.forgot_password_handler for a default handler. *)
let%server forgot_password_service =
  Eliom_service.create
    ~name:"lost_password"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit,
          Eliom_parameter.string "email"))
    ()

(** A POST service to update the basic user data like first name, last name and
    password.
    See {!Os_handlers.set_personal_data_handler for a default handler. *)
let%server set_personal_data_service =
  Eliom_service.create
    ~name:"set_data"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit,
          (string "firstname" ** string "lastname") **
          (string "password"  ** string "password2")))
    ()

(** A POST service to sign up with only an email address.
    See {!Os_handlers.sign_up_handler for a default handler. *)
let%server sign_up_service =
  Eliom_service.create
    ~name:"sign_up"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit,
          Eliom_parameter.string "email"))
    ()

(** A POST service to connect a user with username and password.
    See {!Os_handlers.connect_handler for a default handler. *)
let%server connect_service =
  Eliom_service.create
    ~name:"connect"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit,
          ((string "username" ** string "password") **
           bool "keepmeloggedin")))
    ()

(** A POST service to disconnect the current user.
    See {!Os_handlers.disconnect_handler} for a default handler. *)
let%server disconnect_service =
  Eliom_service.create
    ~name:"disconnect"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit, Eliom_parameter.unit))
    ()

(** A GET service for action link keys.
    See {!Os_handlers.action_link_handler} for a default handler and
    {!Os_db.action_link_table} for more information about the action
    process. *)
let%server action_link_service =
  Eliom_service.create
    ~name:"action_link"
    ~path:Eliom_service.No_path
    ~meth:(Eliom_service.Get (Eliom_parameter.string "actionkey"))
    ()

(** A POST service to update the password. An update password action is
    associated with the confirmation password.
    See {!Os_handlers.set_password_handler} for a default handler. *)
let%server set_password_service =
  Eliom_service.create
    ~name:"set_password"
    ~path:Eliom_service.No_path
    ~meth:
      (Eliom_service.Post
         (Eliom_parameter.unit,
          string "password" ** string "password2"))
    ()

(** A POST service to add an email to a user.
    See {!Os_handlers.add_email_handler} for a default handler. *)
let%server add_email_service = Eliom_service.create
  ~name:"add_email"
  ~path:Eliom_service.No_path
  ~meth:(Eliom_service.Post (
    Eliom_parameter.unit,
    Eliom_parameter.string "email"
  )) ()

let%client main_service = ~%main_service
let%client preregister_service = ~%preregister_service
let%client forgot_password_service = ~%forgot_password_service
let%client set_personal_data_service = ~%set_personal_data_service
let%client sign_up_service = ~%sign_up_service
let%client connect_service = ~%connect_service
let%client disconnect_service = ~%disconnect_service
let%client action_link_service = ~%action_link_service
let%client set_password_service = ~%set_password_service
let%client add_email_service = ~%add_email_service
