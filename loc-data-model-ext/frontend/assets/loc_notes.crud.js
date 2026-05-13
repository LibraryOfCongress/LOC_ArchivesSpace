/*
  See notes.crud.js.erb in core. Initializers are recreated here for
  the new unordered list note subrecord template.
*/

$(function() {

  function activateAddItem ($subform) {
    $('.add-item-btn', $subform).click(function (event) {
      event.preventDefault();
      event.stopPropagation();

      var template = "template_orderedlist_item";

      var context = $(this).parent().hasClass('controls')
	? $(this).parent()
	: $(this).closest('.subrecord-form');
      var $target_subrecord_list = $('.subrecord-form-list:first', context);
      var add_data_index = nextDataIndex($target_subrecord_list);

      var $subsubform = $(
	AS.renderTemplate(template, {
	  path: AS.quickTemplate($target_subrecord_list.data('name-path'), {
	    index: add_data_index,
	  }),
	  id_path: AS.quickTemplate(
	    $target_subrecord_list.data('id-path'),
	    { index: add_data_index }
	  ),
	  index: '${index}',
	})
      );

      $subsubform = $('<li>')
	.data('type', $subsubform.data('type'))
	.append($subsubform);
      $subsubform.attr('data-index', add_data_index);
      $target_subrecord_list.append($subsubform);

      AS.initSubRecordSorting($target_subrecord_list);

      initNoteForm($subsubform, false);

      $subform.parents('form:first').triggerHandler('formchanged.aspace');

      $(':input:visible:first', $subsubform).focus();
    });
  }

  function nextDataIndex ($list) {
    var data_indexes = $list
      .children()
      .map(function () {
	return parseInt($(this).attr('data-index'));
      })
      .get();
    return data_indexes.length > 0 ? Math.max.apply(Math, data_indexes) + 1 : 0;
  }

  function initNoteForm ($noteform, for_a_new_form) {
    if ($noteform.hasClass('initialised')) {
      return;
    }
    $noteform.addClass('initialised');

    if (!for_a_new_form) initRemoveActionForSubRecord($noteform);

    dropdownFocusFix($noteform);

    var $list = $('ul.subrecord-form-list:first', $noteform);

    AS.initSubRecordSorting($list);

    var note_type = $noteform.data('type');

    initContentList($noteform);
    initCollapsible($noteform);
  };

  function dropdownFocusFix (form) {
    $('.dropdown-menu.subrecord-selector li', form).click(function (e) {
      if (!$(e.target).hasClass('btn')) {
	// Don't hide the dropdown unless what we clicked on was the "Add" button itself.
	e.stopPropagation();
      }
    });
  };


  function initRemoveActionForSubRecord ($subform) {
    var removeBtn = $(
      "<a href='javascript:void(0)' class='btn btn-sm btn-default float-right m-2 subrecord-form-remove' title='remove-subrecord' aria-label='remove-subrecord''><span class='glyphicon glyphicon-remove'></span></a>"
    );
    $subform.prepend(removeBtn);
    removeBtn.on('click', function () {
      AS.confirmSubFormDelete($(this), function () {
	if ($subform.parent().hasClass('subrecord-form-wrapper')) {
	  $subform.parent().remove();
	} else {
	  $subform.remove();
	}
	$this.parents('form:first').triggerHandler('formchanged.aspace');
	$(document).triggerHandler('subrecorddeleted.aspace', [$this]);
      });
    });
  };

  $(document).ready(function () {
    $(document).bind('loadedrecordform.aspace', function (event, $container) {
      $(
	'.subrecord-form-fields',
	$container
      ).each(function () {
	var $subform = $(this);
	if ($subform.data('type') == "note_unorderedlist") {
	  activateAddItem($subform);
	}
      });
    });

    $(document).bind(
      'subrecordcreated.aspace',
      function (event, type, $subform) {
	if ($subform.data('type') == 'note_unorderedlist') {
	  activateAddItem($subform);
	}
      }
    );
  });
});
