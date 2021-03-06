import 'package:angular/angular.dart';

import 'date_picker.dart';

import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fontawesome/directives.dart';

/// Creates an [EsDayPickerComponent], this will be the view showed in the [NgEsDatePicker] when user clicks
/// day header button
@Component(
    selector: 'es-day-picker',
    templateUrl: 'day_picker.html',
    directives: [coreDirectives, fontAwesomeDirectives])
class EsDayPickerComponent {
  /// provides access to [EsDatePickerComponent] parent container
  EsDatePickerComponent datePicker;

  void toggleMode(event, [num direction]) {
    event.stopPropagation();
    datePicker.toggleMode(direction);
  }

  void move(event, num direction) {
    event.stopPropagation();
    datePicker.move(direction);
  }

  @Input()
  String locale = 'pt_BR';

  /// labels of the days week
  List<Map<String, String>> labels = [];

  /// provides the label that will appears in the month button of day view
  String monthTitle;

  /// provides the label that will appears in the year button of day view
  String yearTitle;

  /// provides the rows of days that will be displayed
  List<List<DisplayedDate>> rows = <List<DisplayedDate>>[];

  /// provides the values of the week numbers column
  List<num> weekNumbers = [];

  /// provides the maximun mode that can be displayed
  String maxMode = 'year';

  Map<String, bool> selectColorBtn(DisplayedDate dt) => {
        'btn-primary': dt.selected,
        'btn-light': !dt.selected,
        'active': dt.current,
        'disabled': dt.disabled
      };
  Map<String, bool> typeTextToButton(DisplayedDate dt) => {
        'text-muted': dt.secondary,
        'font-weight-bold': dt.current && !dt.selected
      };

  bool get isDisabledMaxMode => datePicker.datePickerMode == maxMode;

  ///
  List<DateTime> getDates(DateTime startDate, num n) {
    var dates = List<DateTime>(n);
    var current = startDate;
    var i = 0;
    var date;
    while (i < n) {
      date = current;
      dates[i++] = date;
      current = current.add(Duration(days: 1));
    }
    return dates;
  }

  ///
  num getISO8601WeekNumber(DateTime checkDate) {
    // ISO week date weeks start on monday
    // so correct the day number
    var dayNr = (checkDate.weekday + 6) % 7;

    // ISO 8601 states that week 1 is the week
    // with the first thursday of that year.
    // Set the target date to the thursday in the target week
    var thisMonday = checkDate.subtract(Duration(days: (dayNr)));
    var thisThursday = thisMonday.add(Duration(days: 3));

    // Set the target to the first thursday of the year
    // First set the target to january first
    var firstThursday = DateTime(checkDate.year, DateTime.january, 1);

    if (firstThursday.weekday != (DateTime.thursday)) {
      firstThursday = DateTime(checkDate.year, DateTime.january,
          1 + ((4 - firstThursday.weekday) + 7) % 7);
    }

    // The weeknumber is the number of weeks between the
    // first thursday of the year and the thursday in the target week
    return (thisThursday.difference(firstThursday).inDays / 7).ceil();
  }

  void refreshViewHandler() {
    var initDate = datePicker.initDate;
    num year = initDate.year;
    num month = initDate.month;
    var firstDayOfMonth =
        DateTime(year, month, 1 - DateTime(year, month, 1, 12).weekday, 12);
    var difference = datePicker.startingDay - firstDayOfMonth.day;
    var numDisplayedFromPreviousMonth =
        (difference > 0) ? 7 - difference : -difference;
    var firstDate = firstDayOfMonth;
    if (numDisplayedFromPreviousMonth > 0) {
      //todo luisvt: not sure what to do with next line
//        firstDate.setDate(-numDisplayedFromPreviousMonth + 1);
    }
    // 42 is the number of days on a six-week calendar
    var _days = getDates(firstDate, 42);
    var days = <DisplayedDate>[];
    for (num i = 0; i < 42; i++) {
      var _dateObject =
          datePicker.createDateObject(_days[i], datePicker.formatDay);
      _dateObject.secondary = _days[i].month != month;
      days.add(_dateObject);
    }
    labels = [];
    for (num j = 0; j < 7; j++) {
      labels.add({
        'abbr': datePicker.dateFilter(days[j].date, datePicker.formatDayHeader),
        'full': datePicker.dateFilter(days[j].date, 'EEEE')
      });
    }
    initializeDateFormatting(locale);
    monthTitle =
        DateFormat(datePicker.formatMonthTitle, locale).format(initDate);
    yearTitle = DateFormat(datePicker.formatYear, locale).format(initDate);
    rows = datePicker.split(days, 7);
    //if (datePicker.showWeeks) {
    weekNumbers.clear();
    num thursdayIndex = (4 + 7 - datePicker.startingDay) % 7,
        numWeeks = rows.length;
    for (num curWeek = 0; curWeek < numWeeks; curWeek++) {
      weekNumbers
          .add(getISO8601WeekNumber(rows[curWeek][thursdayIndex].date) + 1);
    }
    //}
  }
}
