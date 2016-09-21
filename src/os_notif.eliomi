(* Ocsigen-start
 * http://www.ocsigen.org/ocsigen-start
 *
 * Copyright (C) 2014
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

(** Server to client notifications.

    This module makes possible for client side applications to be
    notified of changes on some indexed data on the server.

    Apply functor [Make] for each type of data you want to be able to listen on.
    Each client starts listening on one piece of data by calling function
    [listen] with the index of that piece of data as parameter.
    Client stops listening by calling function [unlisten],
    or when the client side state is closed (by timeout or when the user
    logs out for example).

    When the data is modified on server side, call function [notify]
    with the index of the data, and all clients listening to that piece
    of data will receive a notification. Function [notify] takes as parameter
    the function that will build a customize notification for each user.
    (Be careful to check that user has right to see this data at this moment).

    The functor will also create a client side react signal that will
    be updated every time the client is notified.
*)

module Make(A : sig type key type notification end) :
sig

  (** Make client process listen on data whose index is [key] *)
  val listen : A.key -> unit

  (** Stop listening on data [key] *)
  val unlisten : A.key -> unit

  (** Make a user stop listening on data [key] *)
  val unlisten_user :
    ?sitedata:Eliom_common.sitedata -> userid:Os_user.id -> A.key -> unit

  (** handles notifications received as a broadcast from another server
  *)
  val receive_broadcast : A.key -> A.notification option Lwt.t -> unit Lwt.t

  (** Call [notify id f] to send a notification to all clients currently
      listening on data [key]. The notification is build using function [f],
      that takes the userid as parameter, if a user is connected for this
      client process.

      If you do not want to send the notification for this user,
      for example because he is not allowed to see this data,
      make function [f] return [None].

      If [~notforme] is [true], notification will not be sent to the tab
      currently doing the request (the one which caused the notification to
      happen). Default is [false].

      If a function [broadcast] is supplied then instead of handling the
      notification [notify] feeds its message to that function, which is
      supposed to broadcast the message to other servers. See also
      [receive_broadcast] which handles broadcast messages. Note, that the
      transport between servers is not supplied by this module. Note also that
      the [broadcast] function always supplies [None] to the messages content
      generator, so this might break some applications!
  *)
  val notify :
    ?broadcast:(A.key -> A.notification -> unit Lwt.t) ->
    ?notforme:bool -> A.key -> (int64 option -> A.notification option Lwt.t) ->
    unit

  (** Returns the client react event. Map a function on this event to react
      to notifications from the server.
      For example:
[{server{
  let _ = Os_session.on_start_process
    (fun () ->
       ignore {unit{ ignore (React.E.map handle_notif %(N.client_ev ())) }};
       Lwt.return ()
     )
}}
]

  *)
  val client_ev : unit -> (A.key * A.notification) Eliom_react.Down.t

end
