$(function() {
  $.fn.disable_publish_actions = function() {
    $(this).each(function() {
      var $this = $(this);
      $("#accession_publish_", $this).prop('disabled', true);
    });
  }

  var $accession_form = $("#accession_form")
  $accession_form.disable_publish_actions();
});
