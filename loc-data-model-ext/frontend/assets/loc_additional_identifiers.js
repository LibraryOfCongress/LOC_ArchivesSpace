$(function() {

  function initRemoveButton($btn) {
    $btn.click(function(e) {
      e.preventDefault();
      e.stopPropagation();
      $btn[0].parentNode.parentNode.remove();
    });
  };


  $.fn.loc_init_additional_identifiers = function() {

    $('button.add-identifier-btn', $(this)).each(function() {
      $(this).click(function(e) {
	e.preventDefault();
	e.stopPropagation();
	const data = {
	  id_path: "archival_object",
	  path: "archival_object"
	}
	const $item_input = $(AS.renderTemplate("template_additional_identifiers_item", data));
	$("#additional_identifiers_input .add-identifier-btn").before($item_input);
	initRemoveButton($("button.remove-identifier-btn", $item_input));
      });
    });

    $("button.remove-identifier-btn", $(this)).each(function() {
      initRemoveButton($(this));
    });
  }

  $(document).bind("loadedrecordform.aspace", function(event, $container) {
    $(".loc-additional-identifiers", $container).loc_init_additional_identifiers();
  });
});
