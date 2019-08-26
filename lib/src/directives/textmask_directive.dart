import 'dart:html';

import 'package:angular/angular.dart';

class TextMaskConfig {
  final String mask;
  final int maxLength;
  TextMaskConfig({this.mask = "xxx.xxx.xxx-xx", this.maxLength = 14});
}

@Directive(selector: '[textMask]')
class TextMaskDirective extends OnChanges {
  @Input()
  Map<String, String> textMask;

  String mask = "xxx.xxx.xxx-xx";
  int maxLength = 14;
  String escapeCharacter = "x";
  InputElement inputElement;
  final Element _el;
  var lastTextSize = 0;
  var lastTextValue = "";

  TextMaskDirective(this._el) {
    if (textMask != null) {
      mask = textMask.containsKey('mask') ? textMask['mask'] : null;
      maxLength = textMask.containsKey('maxLength') && textMask['mask'] != null ? textMask['mask'] : mask?.length;
    }
    lastTextSize = 0;
    inputElement = _el;
    inputElement.onInput.listen((e) {
      _onChange();
      print(textMask);
    });
  }

  void _onChange() {
    var text = inputElement.value;

    if (mask != null) {
      if (text.length <= mask.length) {
        // its deleting text
        if (text.length < lastTextSize) {
          if (mask[text.length] != escapeCharacter) {
            //inputElement.focus();
            inputElement.setSelectionRange(inputElement.value.length, inputElement.value.length);
            inputElement.select();
          }
        } else {
          // its typing
          if (text.length >= lastTextSize) {
            var position = text.length;
            position = position <= 0 ? 1 : position;
            if (position < mask.length - 1) {
              if ((mask[position - 1] != escapeCharacter) && (text[position - 1] != mask[position - 1])) {
                inputElement.value = _buildText(text);
              }
              if (mask[position] != escapeCharacter) {
                inputElement.value = "${inputElement.value}${mask[position]}";
              }
            }
          }

          if (inputElement.selectionStart < inputElement.value.length) {
            inputElement.setSelectionRange(inputElement.value.length, inputElement.value.length);
            inputElement.select();
          }
        }
        // update cursor position
        lastTextSize = inputElement.value.length;
        lastTextValue = inputElement.value;
      } else {
        inputElement.value = lastTextValue;
      }
    } //mask != null
  }

  /*@HostListener('mouseenter')
  void onMouseEnter() {
    print('mouseenter');
  }

  @HostListener('onpaste')
  void onPaste() {
    print('onpaste');
  }*/

  @override
  ngOnChanges(Map<String, SimpleChange> changes) {
    //print('ngOnChanges');
  }

  String _buildText(String text) {
    var result = "";
    for (int i = 0; i < text.length - 1; i++) {
      result += text[i];
    }
    result += mask[text.length - 1];
    result += text[text.length - 1];
    return result;
  }

  _selectText(int start, int end) {
    //inputElement.setSelectionRange(start, end);
    if (window.getSelection != null) {
      var selection = window.getSelection();
      var range = document.createRange();
      range.selectNodeContents(inputElement);
      selection.removeAllRanges();
      selection.addRange(range);
    } else {
      print("Could not select text in node: Unsupported browser.");
    }
  }

  bool _isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.parse(s, (e) => null) != null;
  }
}