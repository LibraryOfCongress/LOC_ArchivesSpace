$(function() {

  var scrollShadow = (function() {
    var elem, width, height, offset,
      shadowTop, shadowBottom,
	timeout, needsUpdate;

    function initShadows() {
      shadowTop = $("<div>")
	.addClass("shadow-top")
	.insertAfter(elem);
      shadowBottom = $("<div>")
	.addClass("shadow-bottom")
	.insertAfter(elem);
    }

    function calcPosition() {
      width = elem.outerWidth();
      height = elem.outerHeight();
      offset = elem.position();

      // update
      shadowTop.css({
	width: width + "px",
	top: offset.top + "px",
	left: offset.left + "px"
      });
      shadowBottom.css({
	width: width + "px",
	top: (offset.top + height - 20) + "px",
	left: offset.left + "px"
      });

      needsUpdate = false;
    }

    function addScrollListener() {
      elem.off("scroll.shadow");
      elem.on("scroll.shadow", function() {
	if (needsUpdate) {
	  calcPosition();
	}

	if (elem.scrollTop() > 0) {
	  shadowTop.fadeIn(125);
	} else {
	  shadowTop.fadeOut(125);
	}
	if (Math.round(elem.scrollTop() + height) >= elem[0].scrollHeight) {
	  shadowBottom.fadeOut(125);
	} else {
	  shadowBottom.fadeIn(125);
	}
      });
    }

    function addResizeListener() {
      $(window).resize(function() {
	clearTimeout(timeout);
	timeout = setTimeout(function() {
	  calcPosition();
	  elem.trigger("scroll.shadow");
	}, 10);
      });
    }

    return {
      init: function(scrollContainer) {
	elem = $(scrollContainer);
	initShadows();
	calcPosition();
	addScrollListener();
	addResizeListener();
	elem.trigger("scroll.shadow");
      },
      update: function() {
	calcPosition();
      },
      requireUpdate: function() {
	needsUpdate = true;
      }
    };

  }());


  const infiniteContainer = document.querySelector("#infinite-records-container");

  if (infiniteContainer != undefined) {
    const sidebar_height = $('#sidebar').height();
    $(infiniteContainer).height(sidebar_height);
    setTimeout(function() {
      scrollShadow.init(infiniteContainer);

      const loadAllSection = document.querySelector('#load-all-section');
      if (loadAllSection != undefined) {

	const loadAllInput = document.querySelector('#load-all-state');
	// if the user clicks "all at once"
	loadAllInput.addEventListener('input', () => {
	  setTimeout(function() {
	    scrollShadow.requireUpdate();
	  }, 600);
	});

	// if the waypoints all get populated the message bar will disappear
	$(infiniteContainer).on("scroll.shadow", function() {
	  setTimeout(function() {
	    if (loadAllSection.style['display'] == 'none') {
	      scrollShadow.update();
	    }
	  }, 600);
	});
      }
    }, 500);
  }

});
