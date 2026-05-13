$(function() {
  $.fn.disable_publish_actions = function() {

    $(this).each(function() {
      var $this = $(this);
      if (USER_CAN_PUBLISH) {
	// nothing to do
      } else {
	// no publish for you!
	$("#resource_publish_", $this).prop('disabled', true);
	$("#archival_object_publish_", $this).prop('disabled', true);
	$('button[data-target$="publish"]').each(function(i, btn) {
	  $(btn).prop('disabled', true);
	});
      }
    });
  }

  $(document).bind(
    "loadedrecordform.aspace",
    function(event, $container) {
      var $resource_form = $("#resource_form", $container)
      // hard to identify the read-only form by content type,
      // so we rely on the DISABLE_PUBLISH flag.
      if (typeof DISABLE_PUBLISH === 'undefined') {
	// do nothing, we aren't in a resource form
      } else if ($resource_form.length < 1 && DISABLE_PUBLISH) {
	$container.disable_publish_actions();
      } else {
	$resource_form.disable_publish_actions();
      }
      var $archival_object_form = $("#archival_object_form", $container)
      $archival_object_form.disable_publish_actions();
    });
});
