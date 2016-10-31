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

[%%shared.start]

(** Call this function either from client or server side
    to display an error message in the page.
    The message is displayed in a special box (a div with id [os_msg]
    created automatically in the body of the page).
    It is displayed during a short amount of time then disappears. You may
    change the duration in seconds with the parameter [duration] (default 2
    seconds).
    The two levels correspond to different classes that you can
    personalize by modifying the CSS class [os_err] (added for error messages to
    the box with ID os_msg).

    If [~onload] is [true], the message is displayed after the next page
    is displayed (default [false]). When called on server side, this is
    always the case.
*)
val msg :
  ?level:[`Err | `Msg] -> ?duration:float -> ?onload:bool -> string -> unit
