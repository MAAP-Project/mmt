function buildJsonForPage() {
  var jsonForPage = {};
  $('.validate').each(function( index ) {
    if ($(this).val().length != 0) { // skip fields that are empty
      // Get the path of this
      var thisPathArray = getObjPathArray($(this));
      // Build the json for this, given its pathArray
      var jsonForThis = buildJsonToValidate($(this), thisPathArray);
      // Add this's path to jsonForPage
      jsonForPage = $.extend(jsonForPage, jsonForThis);
    }
  });
  return jsonForPage;
}

// Given an error path value (i.e. 'X.Y.1.CamelCase'), figure out what the obj id should be
function pathToObjId(path) {
  var objId = 'draft.' + path;
  // Camel to snake
  objId = objId.replace(/\UUID/g, 'Uuid');
  objId = objId.replace(/\URL/g, 'Url');
  objId = objId.replace(/\ISBN/g, 'Isbn');
  objId = objId.replace(/\DOI/g, 'Doi');
  objId = objId.replace(/([A-Z])/g, function($1){return "_"+$1.toLowerCase();});
  objId = objId.replace(/\._/g, '_');
  objId = objId.replace(/\./g, '_');
  return objId;
}

function handleFormValidation(updateInlineErrors) {

  var errorArray = [];
  var jsonForPage = buildJsonForPage();
  var validate = jsen(globalJsonSchema, {greedy: true});
  var valid = validate(jsonForPage);

  // Because our required fields are spread over multiple pages and we only validated this one, there will always be errors

  // Ignore errors for objects that are not in this DOM (i.e. they lack an ID present on this page)
  var relevantErrors = [];
  for(i=0; i<validate.errors.length; i++) {
    var error = validate.errors[i];
    var objId = pathToObjId(error['path']);
    if (obj = document.getElementById(objId)) {
      error['obj'] = obj;
      relevantErrors.push(error);
    }
  }
  
  // Remove previous Summary error display element (if any)
  var summaryErrorDisplayId = 'summary_error_display';
  var errorDisplay = document.getElementById(summaryErrorDisplayId);
  if (errorDisplay) {
    errorDisplay.parentNode.removeChild(errorDisplay);
  }

  if (relevantErrors.length > 0) {

    // Make sure the errors are sorted by path
    relevantErrors = relevantErrors.sort(function(a, b){
      return a.path == b.path ? 0 : +(a.path > b.path) || -1;
    });

    var newElement = '<div id="' + summaryErrorDisplayId + '" class="banner banner-danger"><i class="fa fa-exclamation-triangle"></i>' +
      'Click on an error to go directly to that field:</br>';

    for (i = 0; i < relevantErrors.length; i++) {
      var error = relevantErrors[i];
      var objId = error.obj.id;
      var fieldName = error['path']; //extractFieldName(error['path']);
      var errorString = '<a href="javascript:scrollToLabel(\'' + objId + '\');">' +
        '<important>' + objId + '</important>' + ': ' + error['keyword'] + '.</a></br>';
      newElement += errorString;
    }
    newElement += '</div>';

    // Insert in the proper DOM location
    var element = document.getElementsByClassName('nav-top');
    element[0].insertAdjacentHTML('afterend', newElement);

    if (updateInlineErrors) {
      for (var i = 0; i < relevantErrors.length; i++) {
        var errorsForThisObj = [];
        var indexToObj = i;
        for (var j = i; j < relevantErrors.length; j++) {
          if (relevantErrors[i].obj === relevantErrors[j].obj) {
            errorsForThisObj.push(relevantErrors[j]);
          }
          else {
            i = j - 1;
            break;
          }
        }
        updateInlineErrorsForField(relevantErrors[indexToObj].obj, errorsForThisObj);
      }
    }

    return confirm ('This page has invalid data. Are you sure you want to save it and proceed?')
  }

  return true;
}

function getInlineErrorDisplayId (obj) {
  var objId = obj['id'];
  if (objId == undefined)
    objId = obj.attr('id');
  return objId + '_errors';
}

function updateInlineErrorsForField(obj, errorArray) {

  removeDisplayedInlineErrorsForField(obj);

  // Display new error element under field
  var inlineErrorDisplayId = getInlineErrorDisplayId(obj);
  if (errorArray.length > 0) {
    var newObj = '<div id="' + inlineErrorDisplayId + '" class="banner banner-danger error-display"><i class="fa fa-exclamation-triangle"></i>';
    for(i=0; i<errorArray.length; i++) {
      error = errorArray[i];
      newObj += 'Path = "' + error.path + '" Keyword = "' + error.keyword + '"' + '.</br>';
    }
    newObj += '</div>';
    $(newObj).insertAfter('#' + obj.attr('id'));
  }

}

// Return an array of all the path element strings
function getObjPathArray(obj) {
  var objPathArray = obj.attr('name').replace(/]/g, '').split('[').reverse();
  objPathArray.pop(); // Removes "Draft", the last element of the array

  for (i=0; i<objPathArray.length; i++) {
    if (objPathArray[i].length > 0) {
      objPathArray[i] = snakeToCamel(objPathArray[i]);
      if (objPathArray[i] == 'Doi')
        objPathArray[i] = 'DOI';
      else
        if (objPathArray[i] == 'Isbn')
          objPathArray[i] = 'ISBN';
        else
          if (objPathArray[i] == 'Url')
            objPathArray[i] = 'URL';
          else
            if (objPathArray[i] == 'Uuid')
              objPathArray[i] = 'UUID';
    }
  }
  return objPathArray;
}

// Build json for this object and all its ancestors
function buildJsonToValidate(obj, objPathArray) {
  var schema = {};
  schema[objPathArray[0]] = obj.val();

  for (i=1; i<objPathArray.length; i++) {
    // TODO - find more efficient way of adding outer layers of json to a json object
    var oldSchema = JSON.parse(JSON.stringify(schema)); // clone the json before adding it
    schema = {};
    if (objPathArray[i].match(/^[0-9]+$/) == null) {
      schema[objPathArray[i]] = oldSchema;
    }
    else { // handle arrays
      schema = [oldSchema];
    }
  }
  return schema;
}

// Return just the errors that are relevant to this obj
function collectRelevantErrors(obj, objPathArray, errors) {

  var relevantErrors = [];
  var targetObjId = obj.attr('id');

  for (var i=0; i<errors.length; i++) {
    var error = errors[i];
    //alert('Checking ' + errors[i].path + ' for ' + objPathArray[0] + ' Finding ' + errors[i].path.indexOf(objPathArray[0]));
    var objId = pathToObjId(error['path']);
    if (targetObjId === objId) {
      error['obj'] = obj;
      relevantErrors.push(error);
    }
  }
  return relevantErrors;
}

function removeDisplayedInlineErrorsForField(obj) {
  // Remove previous inline error display element (if any)
  var inlineErrorDisplayId = getInlineErrorDisplayId(obj);
  var errorDisplay = document.getElementById(inlineErrorDisplayId);
  if (errorDisplay) {
    errorDisplay.parentNode.removeChild(errorDisplay);
  }
}

function handleFieldValidation(obj) {

  //try {

  //removeDisplayedInlineErrorsForField(obj);

    // Get the path array of the obj here because it will be used in multiple places
    var objPathArray = getObjPathArray(obj);

    var jsonForPage = buildJsonForPage();

    var validate = jsen(globalJsonSchema, {greedy: true});

    var valid = validate(jsonForPage);

    // Remove errors that do not apply
    var errorArray = collectRelevantErrors(obj, objPathArray, validate.errors);

    updateInlineErrorsForField(obj, errorArray);

  //} catch (e) {
  //  console.log(e);
  //}

  return errorArray;

}

function scrollToLabel(target) {
  // Find the label for this target & scroll it into view. If no label, scroll to the field itself
  var label = $("label[for='" + target + "']")[0];
  if (label)
    label.scrollIntoView( true );
  else
    $('#' + target)[0].scrollIntoView( true );
}

function snakeToCamel(str){
  var newStr = str.replace(/(\_\w)/g, function(m){return m[1].toUpperCase();});
  newStr = newStr[0].toUpperCase() + newStr.slice(1);
  return newStr;
}

$(document).ready(function() {

  var validate = null; // Validate object is null until handleFieldValidation needs it

  // set up validation call
  $('.validate').blur(function(e) {
    handleFieldValidation ($(this));
  });
  
  // Handle form navigation
  $('.next-section').change(function() {
    if (handleFormValidation(true)) {
      $('#new_form_name').val(this.value);
      this.form.submit();
    }
  });

});

