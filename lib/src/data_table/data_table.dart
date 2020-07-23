import 'dart:async';
import 'dart:html';
import 'package:angular/angular.dart';
import 'package:angular/core.dart';
import 'package:angular/security.dart';
//import 'package:angular_components/angular_components.dart';
import 'package:angular_forms/angular_forms.dart';
import 'package:angular_router/angular_router.dart';

import 'package:essential_xlsx/essential_xlsx.dart';
import 'package:intl/intl.dart';

import 'datatable_render_interface.dart';
import 'package:essential_rest/essential_rest.dart';
import 'data_table_filter.dart';
import '../directives/essential_inner_html_directive.dart';
import 'pagination_item.dart';

//utils
import 'data_table_utils.dart';

@Component(
  selector: 'es-data-table',
  templateUrl: 'data_table.html',
  styleUrls: [
    'data_table.css',
  ],
  pipes: [commonPipes],
  directives: [
    formDirectives,
    coreDirectives,
    EssentialInnerHTMLDirective,
  ],
)
//A Material Design Data table component for AngularDart
class EssentialDataTableComponent implements OnInit, AfterChanges, AfterViewInit {
  @ViewChild('tableElement') //HtmlElement
  TableElement tableElement;

  @ViewChild('divNoContent')
  DivElement divNoContent;

  DataTableFilter dataTableFilter = DataTableFilter();

  @ViewChild('inputSearchElement')
  InputElement inputSearchElement;

  @ViewChild('itemsPerPageElement')
  SelectElement itemsPerPageElement;

  @ViewChild('paginateContainer')
  HtmlElement paginateContainer;

  @ViewChild('paginateDiv')
  HtmlElement paginateDiv;

  @ViewChild('paginatePrevBtn')
  HtmlElement paginatePrevBtn;

  @ViewChild('paginateNextBtn')
  HtmlElement paginateNextBtn;

  String _orderDir = 'asc';
  bool _isTitlesRendered = false;

  @Input()
  bool error = false;

  @Input()
  bool isNoContent = false;

  @Input()
  String noContentMessage = 'Dados indisponiveis';

  @Input()
  String errorMessage =
      'Ocorreu um erro ao listar, verifique sua conexão de rede ou entre em contato com o suporte técnico.';

  void setErrorOccurred() {
    isLoading = false;
    error = true;
  }

  void removeErrorOccurred() {
    error = false;
  }

  @Input()
  bool showResetButtom = true;

  @Input()
  bool showActionsHeader = true;

  @Input()
  bool showActionsFooter = true;

  @Input()
  bool showTableHeader = true;

  @Input()
  bool enableOrdering = true;

  @Input()
  bool showFilter = true;

  @Input()
  bool showItemsLimit = true;

  bool showCheckBoxToSelectRow = true;

  @Input()
  set showCheckboxSelect(bool showCBSelect) {
    showCheckBoxToSelectRow = showCBSelect;
  }

  bool get showCheckboxSelect {
    return showCheckBoxToSelectRow;
  }

  RList<IDataTableRender> _data;
  RList<IDataTableRender> selectedItems = RList<IDataTableRender>();

  @Input()
  String itensPerPageInputLabel = 'Exibir:';

  @Input()
  String searchInputLabel = 'Filtrar:';

  @Input()
  String totalRecordsLabel = 'Total:';

  @Input()
  String reloadButtonTitle = 'Recarrega o Datatable';

  @Input()
  String resetButtonTitle = 'Limpar filtros e recarregar';

  @Input()
  String exportButtonTitle = 'Exportar os dados para xlsx';

  @Input()
  String columnVisibilityButtonTitle = 'Visibilidade de colunas';

  @Input()
  set data(RList<IDataTableRender> data) {
    _data = data;
  }

  RList<IDataTableRender> get data {
    return _data;
  }

  int get totalRecords {
    if (_data != null) {
      return _data.totalRecords;
    }
    return 0;
  }

  int _currentPage = 1;
  final int _btnQuantity = 5;
  PaginationType paginationType = PaginationType.carousel;
  List<PaginationItem> paginationItems = <PaginationItem>[];

  EssentialDataTableComponent(this.sanitizer) {
    //dataRequest isLoading
    /* dataRequest.listen((onData){
      print(onData);
    });*/
  }

  //StreamSubscription _prevBtnStreamSub;
  //StreamSubscription _nextBtnStreamSub;

  /*final NodeValidatorBuilder _htmlValidator = NodeValidatorBuilder.common()
    ..allowHtml5()
    ..allowImages()
    ..allowInlineStyles()
    ..allowTextElements()
    ..allowSvg()
    ..allowElement('a', attributes: ['href'])
    ..allowElement('img', attributes: ['src']);*/

  final DomSanitizationService sanitizer;
  //sanitiza o HTML da celula
  SafeHtml getHtmlOfCell(DataTableColumn dataTableColumn, TableCellElement cellElement) {
    return sanitizer.bypassSecurityTrustHtml(formatCell(dataTableColumn, cellElement: cellElement));
  }

  @override
  void ngOnInit() {}

  void handleSearchInputKeypress(e) {
    //e.preventDefault();
    e.stopPropagation();
    if (e.keyCode == KeyCode.ENTER) {
      onSearch();
    }
  }

  @override
  void ngAfterViewInit() {
    /*if (showActionsHeader) {
      inputSearchElement?.onKeyPress?.listen((KeyboardEvent e) {
        //e.preventDefault();
        e.stopPropagation();
        if (e.keyCode == KeyCode.ENTER) {
          onSearch();
        }
      });
    }
    if (showActionsFooter) {
      paginatePrevBtn?.onClick?.listen(prevPage);
      paginateNextBtn?.onClick?.listen(nextPage);
    }*/
  }

  @override
  void ngAfterChanges() {
    //draw();
    drawPagination();
  }

  Future<void> toXLSX() async {
    if (_data != null) {
      if (_data.isNotEmpty) {
        var simplexlsx = SimpleXLSX();
        simplexlsx.sheetName = 'sheet';

        //adiciona os dados
        var idx = 0;
        _data.forEach((item) {
          var col = item.getRowDefinition();
          if (idx == 0) {
            var collsForExport = col.colsSets.where((i) => i.export).toList();
            //adiciona os titulos
            simplexlsx.addRow(collsForExport.map((c) {
              return c.title.toString();
            }).toList());
          }
          {
            var collsForExport = col.colsSets.where((i) => i.export).toList();
            //adiciona os valores
            simplexlsx.addRow(collsForExport.map((c) {
              return formatCell(c, disableLimit: true, stripHtml: true);
            }).toList());
          }
          idx++;
        });

        simplexlsx.build();
      }
    }
  }

  List<DataTableColumn> get columnTitles {
    if (_data != null && _data.isNotEmpty) {
      var columnsTitles = _data[0].getRowDefinition();
      return columnsTitles.colsSets;
    }
    return null;
  }

  void changeVisibilityOfCol(DataTableColumn col) {
    var visible = !col.visible;
    _data.forEach((row) {
      row.getRowDefinition().colsSets.forEach((column) {
        if (column.title == col.title) {
          column.visible = visible;
        }
      });
    });
  }

  /*void draw() {
    try {
      //clear tbody if not get data
      if (_data == null || _data.isEmpty) {
        var tbody = tableElement.querySelector('tbody');
        if (tbody != null) {
          tbody.innerHtml = '';
        } else {
          var tBody = tableElement.createTBody();
          tBody.innerHtml = '';
        }

        isNoContent = true;
        divNoContent.style.display = 'block';
        //print(divNoContent);
        //print(isNoContent);
      }

      if (_data != null) {
        error = false;
        isNoContent = false;
        divNoContent.style.display = 'none';
        if (_data.isNotEmpty) {
          TableSectionElement tBody;
          if (tableElement.querySelector('tbody') == null) {
            tableElement.innerHtml = '';
            tBody = tableElement.createTBody();
          } else {
            tableElement.querySelector('tbody').innerHtml = '';
            tBody = tableElement.querySelector('tbody');
          }

          // Element tableHead =//
          tableElement.createTHead();
          var tableHeaderRow = tableElement.tHead.insertRow(-1);
          //show checkbox on tableHead to select all rows
          if (_showCheckBoxToSelectRow) {
            var th = Element.tag('th');
            th.style.setProperty('text-align', 'left');
            th.attributes['class'] = 'datatable-first-col';
            var label = Element.tag('label');
            label.classes.add('pure-material-checkbox');
            var input = CheckboxInputElement();
            //input.type = "checkbox";
            input.onClick.listen(onSelectAll);
            var span = Element.tag('span');
            label.append(input);
            label.append(span);
            th.append(label);
            tableHeaderRow.insertAdjacentElement('beforeend', th);
          }

          //render colunas de titulo
          var columns = _data[0].getRowDefinition();
          for (var col in columns.colsSets) {
            //    if (col.visible) {
            var th = Element.tag('th');
            th.style.setProperty('text-align', 'left');
            th.attributes['class'] = 'dataTableSorting';
            th.text = col.title;
            //ordenação
            th.onClick.listen((e) {
              if (enableOrdering == true) {
                tableElement.querySelectorAll('th:not(.datatable-first-col)').forEach((el) {
                  el.attributes['class'] = 'dataTableSorting';
                });

                if (_orderDir == 'asc') {
                  _orderDir = 'desc';
                  th.attributes['class'] = 'dataTableSorting dataTableSortingDesc';
                } else if (_orderDir == 'desc') {
                  _orderDir = 'asc';
                  th.attributes['class'] = 'dataTableSorting dataTableSortingAsc';
                }

                dataTableFilter.orderBy = col.key;
                dataTableFilter.orderDir = _orderDir;
                onRequestData();
              }
            });

            // tableHeaderRow.insertAdjacentElement('beforeend', th);
            //}
          }

          //render linhas
          for (final item in _data) {
            var tableRow = tBody.insertRow(-1);
            //show checkbox to select single row
            if (_showCheckBoxToSelectRow) {
              var tdcb = Element.tag('td');
              tdcb.style.setProperty('text-align', 'left');
              tdcb.attributes['class'] = 'datatable-first-col';
              var label = Element.tag('label');
              label.onClick.listen((e) {
                e.stopPropagation();
              });
              label.classes.add('pure-material-checkbox');
              var input = CheckboxInputElement();
              //input.type = "checkbox";
              input.attributes['cbSelect'] = 'true';
              input.onClick.listen((MouseEvent event) {
                onSelect(event, item);
              });
              var span = Element.tag('span');
              span.onClick.listen((e) {
                e.stopPropagation();
              });
              label.append(input);
              label.append(span);
              tdcb.append(label);
              tableRow.insertAdjacentElement('beforeend', tdcb);
            }

            tableRow.onClick.listen((event) {
              onRowClick(item);
            });

            //draw columns
            var colData = item.getRowDefinition();
            for (var colSet in colData.colsSets) {
              print('draw $colSet');
              // if (colSet.visible) {
              var tdContent = '';
              var td = Element.tag('td');
              tableRow.insertAdjacentElement('beforeend', td);
              tdContent = formatCell(colSet, cellElement: td);
              td.style.setProperty('text-align', 'left');
              if (colSet.textColor != null) {
                td.style.setProperty('color', colSet.textColor);
              }
              if (colSet.backgroundColor != null) {
                td.style.setProperty('background', colSet.backgroundColor);
              }
              td.setInnerHtml(tdContent, treeSanitizer: NodeTreeSanitizer.trusted);
              //}
            }
          }
        }
      }
    } catch (exception, stackTrace) {
      print('DataTable@draw() exception: $exception');
      print('DataTable@draw() stackTrace: $stackTrace');
    }
    isLoading = false;
  }*/

  String removeAllHtmlTags(String htmlText) {
    var exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(exp, '');
  }

  String formatCell(DataTableColumn dataTableColumn,
      {bool disableLimit = false, bool stripHtml = false, TableCellElement cellElement}) {
    var tdContent = '';
    if (dataTableColumn.customRender == null) {
      switch (dataTableColumn.type) {
        case DataTableColumnType.date:
          if (dataTableColumn.value != null) {
            var fmt = dataTableColumn.format ?? 'dd/MM/yyyy';
            var formatter = DateFormat(fmt);
            var date = DateTime.tryParse(dataTableColumn.value.toString());
            if (date != null) {
              tdContent = formatter.format(date);
            }
          }
          break;
        case DataTableColumnType.dateTime:
          if (dataTableColumn.value != null) {
            var fmt = dataTableColumn.format ?? 'dd/MM/yyyy HH:mm:ss';
            var formatter = DateFormat(fmt);
            var date = DateTime.tryParse(dataTableColumn.value.toString());
            if (date != null) {
              tdContent = formatter.format(date);
            }
          }
          break;
        case DataTableColumnType.text:
          var str = dataTableColumn.value.toString();
          if (dataTableColumn.limit != null && disableLimit == false) {
            str = DataTableUtils.truncate(str, dataTableColumn.limit);
          }
          str = str == 'null' ? '' : str;
          tdContent = str;
          break;
        case DataTableColumnType.brasilCurrency:
          var str = dataTableColumn.value.toString();
          if (str != '' && str != 'null') {
            final formatCurrency = NumberFormat.simpleCurrency(locale: 'pt_BR');
            str = formatCurrency.format(double.tryParse(str));
            tdContent = str;
          } else {
            tdContent = '';
          }
          break;
        case DataTableColumnType.boolLabel:
          var str = dataTableColumn.value.toString();
          if (stripHtml) {
            tdContent = str;
          } else {
            if (str == 'true') {
              str = '<span class="badge badge-success">Sim</span>';
            } else {
              str = '<span class="badge badge-danger">Não</span>';
            }
          }
          tdContent = str;
          break;
        case DataTableColumnType.badge:
          var str = dataTableColumn.value.toString();
          if (str != '' && str != 'null') {
            if (stripHtml) {
              tdContent = str;
            } else {
              var badgeColor = dataTableColumn.badgeColor != null
                  ? 'background:${dataTableColumn.badgeColor};'
                  : 'background:#e0e0e0;';
              str = '<span class="badge" style="font-size:.8125rem;color:#fff;font-weight:400;$badgeColor">$str</span>';
            }
          } else {
            str = '';
          }
          tdContent = str;
          break;
        case DataTableColumnType.img:
          var src = dataTableColumn.value.toString();
          if (src != 'null') {
            if (stripHtml) {
              tdContent = src;
            } else {
              var img = ImageElement();
              img.src = src;
              img.height = 40;
              tdContent = img.outerHtml;
            }
          } else {
            tdContent = '-';
          }
          break;
        default:
          var str = dataTableColumn.value.toString();
          if (dataTableColumn.limit != null) {
            str = DataTableUtils.truncate(str, dataTableColumn.limit);
          }
          tdContent = str;
      }
    } else {
      tdContent = dataTableColumn.customRender(cellElement);
    }

    if (stripHtml) {
      tdContent = removeAllHtmlTags(tdContent);
    }

    tdContent = tdContent == 'null' ? '-' : tdContent;
    return tdContent;
  }

  int numPages() {
    var totalPages = (totalRecords / dataTableFilter.limit).ceil();
    return totalPages;
  }

  void drawPagination() {
    if (showActionsFooter) {
      var self = this;
      //quantidade total de paginas
      var totalPages = numPages();

      //quantidade de botões de paginação exibidos
      var btnQuantity = self._btnQuantity > totalPages ? totalPages : self._btnQuantity;
      var currentPage = self._currentPage; //pagina atual
      //clear paginateContainer for new draws
      self.paginateContainer?.innerHtml = '';
      if (self.totalRecords < self.dataTableFilter.limit) {
        return;
      }

      if (btnQuantity == 1) {
        return;
      }

      if (currentPage == 1) {
        paginatePrevBtn?.classes?.remove('disabled');
        paginatePrevBtn?.classes?.add('disabled');
      }

      if (currentPage == totalPages) {
        paginateNextBtn?.classes?.remove('disabled');
        paginateNextBtn?.classes?.add('disabled');
      }

      var idx = 0;
      var loopEnd = 0;
      switch (paginationType) {
        case PaginationType.carousel:
          idx = (currentPage - (btnQuantity / 2)).toInt();
          if (idx <= 0) {
            idx = 1;
          }
          loopEnd = idx + btnQuantity;
          if (loopEnd > totalPages) {
            loopEnd = totalPages + 1;
            idx = loopEnd - btnQuantity;
          }
          while (idx < loopEnd) {
            var link = Element.tag('a');
            link.classes.add('paginate_button');
            if (idx == currentPage) {
              link.classes.add('current');
            }
            link.text = idx.toString();
            var liten = (event) {
              var pageBtnValue = int.tryParse(link.text);
              if (self._currentPage != pageBtnValue) {
                self._currentPage = pageBtnValue;
                self.changePage(self._currentPage);
              }
            };
            link.onClick.listen(liten);
            self.paginateContainer?.append(link);
            idx++;
          }
          break;
        case PaginationType.cube:
          var facePosition = (currentPage % btnQuantity) == 0 ? btnQuantity : currentPage % btnQuantity;
          loopEnd = btnQuantity - facePosition + currentPage;
          idx = currentPage - facePosition;
          while (idx < loopEnd) {
            idx++;
            if (idx <= totalPages) {
              var link = Element.tag('a');
              link.classes.add('paginate_button');
              if (idx == currentPage) {
                link.classes.add('current');
              }
              link.text = idx.toString();
              var liten = (event) {
                var pageBtnValue = int.tryParse(link.text);
                if (self._currentPage != pageBtnValue) {
                  self._currentPage = pageBtnValue;
                  self.changePage(self._currentPage);
                }
              };
              link.onClick.listen(liten);
              self.paginateContainer.append(link);
            }
          }
          break;
      }
    }
  }

  void prevPage(Event event) {
    if (_currentPage == 0) {
      return;
    }
    if (_currentPage > 1) {
      _currentPage--;
      changePage(_currentPage);
    }
  }

  void nextPage(Event event) {
    if (_currentPage == numPages()) {
      return;
    }
    if (_currentPage < numPages()) {
      _currentPage++;
      changePage(_currentPage);
    }
  }

  void changePage(page) {
    onRequestData();
    if (page != _currentPage) {
      _currentPage = page;
    }
    selectedItems.clear();
  }

  final _rowClickRequest = StreamController<IDataTableRender>();

  @Output()
  Stream<IDataTableRender> get rowClick => _rowClickRequest.stream;

  void onRowClick(IDataTableRender item) {
    _rowClickRequest.add(item);
  }

  final _searchRequest = StreamController<DataTableFilter>();

  @Output()
  Stream<DataTableFilter> get searchRequest => _searchRequest.stream;

  void onSearch() {
    dataTableFilter.searchString = inputSearchElement.value;
    _searchRequest.add(dataTableFilter);
    onRequestData();
  }

  final _limitChangeRequest = StreamController<DataTableFilter>();

  @Output()
  Stream<DataTableFilter> get limitChange => _limitChangeRequest.stream;

  void onLimitChange() {
    _currentPage = 1;
    dataTableFilter.limit = int.tryParse(itemsPerPageElement.value);
    _limitChangeRequest.add(dataTableFilter);
    onRequestData();
  }

  final _dataRequest = StreamController<DataTableFilter>();

  @Output()
  Stream<DataTableFilter> get dataRequest => _dataRequest.stream;

  bool isLoading = true;

  void onRequestData() {
    isLoading = true;
    var currentPage = _currentPage == 1 ? 0 : _currentPage - 1;
    dataTableFilter.offset = currentPage * dataTableFilter.limit;
    _dataRequest.add(dataTableFilter);
  }

  void reload() {
    onRequestData();
  }

  void reset() {
    itemsPerPageElement.options.firstWhere((o) => o.value == '10').selected = true;
    dataTableFilter.clear();
    onRequestData();
  }

  //quando selecionar tudos os items
  void onSelectAll(event) {
    //event.target.parent.classes.toggle('checked');
    var cbs = tableElement.querySelectorAll('input[cbselect=true]');
    if (event.target.checked) {
      for (CheckboxInputElement item in cbs) {
        item.checked = true;
      }
      selectedItems.clear();
      selectedItems.addAll(_data);
    } else {
      selectedItems.clear();
      for (CheckboxInputElement item in cbs) {
        item.checked = false;
      }
    }
  }

  //quando selecionar um item
  void onSelect(MouseEvent event, IDataTableRender item) {
    event.stopPropagation();
    CheckboxInputElement cb = event.target;
    if (cb.checked) {
      if (selectedItems.contains(item) == false) {
        selectedItems.add(item);
      }
    } else {
      if (selectedItems.contains(item)) {
        selectedItems.remove(item);
      }
    }
  }

  //abre ou fecha menu do dataTable
  void toogleMenu(HtmlElement element) {
    element.style.display = element.style.display != 'block' ? 'block' : 'none';
  }

  void onOrder(DataTableColumn dataTableColumn, TableCellElement cellHeader) {
    if (enableOrdering == true) {
      if (_orderDir == 'asc') {
        _orderDir = 'desc';
      } else if (_orderDir == 'desc') {
        _orderDir = 'asc';
      }

      dataTableFilter.orderBy = dataTableColumn.key;
      dataTableFilter.orderDir = _orderDir;
      onRequestData();
    }
  }
}

enum PaginationType { carousel, cube }
