[%%shared.start]

module Make :
  functor (A : module type of Eliom_content.Html.F) ->
    sig
      val icon :
        Html_types.nmtoken list ->
        ?a:Html_types.i_attrib A.attrib list ->
        unit -> [> Html_types.i ] A.elt
    end

module F :
  sig
    val icon :
      Html_types.nmtoken list ->
      ?a:Html_types.i_attrib Eliom_content.Html.F.attrib list ->
      unit -> [> Html_types.i ] Eliom_content.Html.F.elt
  end

module D :
  sig
    val icon :
      Html_types.nmtoken list ->
      ?a:Html_types.i_attrib Eliom_content.Html.D.attrib list ->
      unit -> [> Html_types.i ] Eliom_content.Html.D.elt
  end
