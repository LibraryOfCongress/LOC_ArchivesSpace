$(function() {
  $('.more-facets__facets').hide();
});

// AS-557: Intercept facet clicks in the capture phase to prevent Adobe Analytics 
// from mangling the URL. stopImmediatePropagation() blocks Adobe's document-level handler
document.addEventListener('click', function(e) {
  var link = e.target.closest ? e.target.closest('#facets a') : null;

  if (link && link.getAttribute('href') && link.getAttribute('href').indexOf('filter_fields') !== -1) {
    e.stopImmediatePropagation();
    e.preventDefault();
    window.location.href = link.getAttribute('href');
  }
}, true);