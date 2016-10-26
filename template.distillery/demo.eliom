(* This file was generated by Ocsigen-start.
   Feel free to use it, modify it, and redistribute it as you wish. *)

[%%shared
  open Eliom_content.Html
  open Eliom_content.Html.D
]

[%%shared
  module type DemoPage = sig
    val name : string

    val service :
      (unit, unit,
       Eliom_service.get,
       Eliom_service.att,
       Eliom_service.non_co,
       Eliom_service.non_ext,
       Eliom_service.reg,
       [ `WithoutSuffix ],
       unit, unit,
       Eliom_service.non_ocaml)
        Eliom_service.t

    val page :
      unit ->
      ([> `Input | `P | `Div] Eliom_content.Html.D.elt) list Lwt.t
  end
]





(* drawer / demo welcome page ***********************************************)

let%shared demos = [
  (module Demo_popup : DemoPage);
  (module Demo_carousel1);
  (module Demo_carousel3);
  (module Demo_rpc);
  (module Demo_calendar);
  (module Demo_timepicker)
]

(* adds a drawer menu to the document body *)
let%shared make_drawer_menu () =
  let menu =
    let make_link (module D : DemoPage) =
      li [a ~service:D.service [pcdata @@ D.name] ()]
    in
    let menu = ul (List.map make_link demos) in
    [div ~a:[a_class ["os-drawer"]] [h3 [pcdata "demo: drawer menu"]; menu]]
  in
  let drawer, _,_ = Ot_drawer.drawer menu in
  drawer

let%shared make_page myid_o content =
  %%%MODULE_NAME%%%_container.page myid_o (
    make_drawer_menu () :: content
  )

let%shared handler myid_o () () = make_page myid_o
  [
    p [pcdata "This page contains some demos for some widgets \
               from ocsigen-toolkit."];
    p [pcdata "The different demos are accessible through the drawer \
               menu. To open it click the top left button on the screen."];
    p [pcdata "Feel free to modify the generated code and use it \
               or redistribute it as you want."];
  ]


let%shared () =
  let registerDemo (module D : DemoPage) =
    %%%MODULE_NAME%%%_base.App.register
      ~service:D.service
      (%%%MODULE_NAME%%%_page.Opt.connected_page @@ fun id () () ->
        let%lwt p = D.page () in
        make_page id p)
  in
  List.iter registerDemo demos;
  %%%MODULE_NAME%%%_base.App.register
    ~service:%%%MODULE_NAME%%%_services.demo_service
    (%%%MODULE_NAME%%%_page.Opt.connected_page handler)
