$(function() {
  $('.more-facets__facets').hide();
});

// AS-557 & AS-566: Intercept facet clicks in the capture phase to prevent Adobe Analytics 
// from mangling the URL. stopImmediatePropagation() blocks Adobe's document-level handler.
// Also encodes XSS characters (<part> tags) so PROD WAF does not drop parameters.
document.addEventListener('click', function(e) {
  var link = e.target.closest ? e.target.closest('a') : null;

  if (link && link.getAttribute('href') && (link.getAttribute('href').indexOf('filter_fields') !== -1 || link.getAttribute('href').indexOf('filter_values') !== -1)) {
    e.stopImmediatePropagation();
    e.preventDefault();

    var url = link.getAttribute('href');
    if (url.indexOf('%3C') !== -1 || url.indexOf('%3E') !== -1) {
      url = url.replace(/%3C/g, '__LT__').replace(/%3E/g, '__GT__');
    }

    window.location.href = url;
  }
}, true);

// AS-566: Encode hidden filter_values inputs when submitting GET forms (like "Search within results")
document.addEventListener('submit', function(e) {
  var form = e.target;
  if (form.method && form.method.toLowerCase() === 'get') {
    var filterValues = form.querySelectorAll('input[name="filter_values[]"]');
    filterValues.forEach(function(input) {
      if (input.value.indexOf('<') !== -1 || input.value.indexOf('>') !== -1) {
        input.value = input.value.replace(/</g, '__LT__').replace(/>/g, '__GT__');
      }
    });
  }
}, true);