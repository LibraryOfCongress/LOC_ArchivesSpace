$(function() {
  $.fn.loc_init_digital_object_form = function() {
    $(this).each(function() {
      var $this = $(this);
      var $eadDaoTypeSelect = $("#digital_object_ead_dao_type_", $this);
      var $otherDaoType = $("#digital_object_other_ead_dao_type_", $this);

      var handleDaoTypeChange = function(initialising) {
	if ($eadDaoTypeSelect.val() === "otherdaotype") {
	  $otherDaoType.attr('disabled', null);
	  if (initialising === true) {
	    $otherDaoType.closest(".form-group").show();
	  } else {
	    $otherDaoType.closest(".form-group").slideDown();
	  }
	} else {
	  $otherDaoType.attr("disabled", "disabled");
	  if (initialising === true) {
	    $otherDaoType.closest(".form-group").hide();
	  } else {
	    $otherDaoType.closest(".form-group").slideUp();
	  }
	}
      };

      handleDaoTypeChange(true);
      $eadDaoTypeSelect.change(handleDaoTypeChange);
    });
  }

  $(document).bind("loadedrecordform.aspace", function(event, $container) {
    $("#new_digital_object", $container).loc_init_digital_object_form();
  });

  $("#new_digital_object").loc_init_digital_object_form();

});
