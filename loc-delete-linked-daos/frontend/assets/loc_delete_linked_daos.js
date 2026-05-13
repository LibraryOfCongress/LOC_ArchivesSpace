$(function() {

  $(document).bind(
    "loadedrecordform.aspace",
    function(event, $container) {
      if (USER_CAN_DELETE_RESOURCE) {
	$('#other-dropdown ul.dropdown-menu').append(
	  AS.renderTemplate('loc_delete_linked_daos_template'))
      }
    });
});
