#
#
#            Aporia - Nimrod IDE
#        (c) Copyright 2011 Dominik Picheta
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import gtk2, gdk2, glib2, pango, os
import gtksourceview, utils
import tables

{.push callConv:cdecl.}

const
  langSpecs* = "share/gtksourceview-2.0/language-specs"
  styles* = "share/gtksourceview-2.0/styles"

var win: ptr utils.MainWin

# -- Fonts and Colors --

proc escapeMarkup(s: string): string =
  result = ""
  var i = 0
  while True:
    case s[i]
    of '&': result.add("&amp;")
    of '<': result.add("&lt;")
    of '>': result.add("&gt;")
    of '\0': break
    else: result.add(s[i])
    inc(i)

proc addSchemes(schemeTree: PTreeView, schemeModel: PListStore) =
  var schemeMan = schemeManagerGetDefault()
  var schemes = cstringArrayToSeq(schemeMan.getSchemeIds())
  for i in countdown(schemes.len() - 1, 0):
    var iter: TTreeIter
    # Add a new TreeIter to the treeview
    schemeModel.append(addr(iter))
    # Get the scheme name and decription
    var scheme = schemeMan.getScheme(schemes[i])
    var name = $scheme.getName()
    var desc = $scheme.getDescription()
    # Set the TreeIter's values
    schemeModel.set(addr(iter), 0, schemes[i], 1, "<b>" & escapeMarkup(name) &
                    "</b> - " & escapeMarkup(desc), -1)

    if schemes[i] == win.globalSettings.colorSchemeID:
      schemeTree.getSelection.selectIter(addr(iter))

proc schemesTreeView_onChanged(selection: PGObject, user_data: pgpointer) =
  var iter: TTreeIter
  var model: PTreeModel
  var value: cstring
  
  if getSelected(PTreeSelection(selection), addr(model), addr(iter)):
    model.get(addr(iter), 0, addr(value), -1)
    win.globalSettings.colorSchemeID = $value

    var schemeMan = schemeManagerGetDefault()
    win.scheme = schemeMan.getScheme(value)
    # Loop through each tab, and set the scheme
    for i in items(win.Tabs):
      i.buffer.setScheme(win.scheme)
      
proc fontDialog_OK(widget: PWidget, user_data: PFontSelectionDialog) =
  PDialog(userData).response(RESPONSE_OK)
  
proc fontDialog_Canc(widget: PWidget, user_data: PFontSelectionDialog) =
  PDialog(userData).response(RESPONSE_CANCEL)

proc fontChangeBtn_Clicked(widget: PWidget, user_data: PEntry) =
  # Initialize the FontDialog
  var fontDialog = fontSelectionDialogNew("Select font")
  fontDialog.setTransientFor(win.w)
  discard fontDialog.dialogSetFontName(win.globalSettings.font)
  
  discard fontDialog.okButton.GSignalConnect("clicked", 
      G_CALLBACK(fontDialog_OK), fontDialog)
  discard fontDialog.cancelButton.GSignalConnect("clicked", 
      G_CALLBACK(fontDialog_Canc), fontDialog)
  
  # This will wait until the user responds(clicks the OK or Cancel button)
  var result = fontDialog.run()
  # If the response, is OK, then change the font.
  if result == RESPONSE_OK:
    win.globalSettings.font = $fontDialog.dialogGetFontName()
    userData.setText(fontDialog.dialogGetFontName())
    # Loop through each tab, and change the font
    for i in items(win.Tabs):
      var font = fontDescriptionFromString(win.globalSettings.font)
      i.sourceView.modifyFont(font)
    
  gtk2.POBject(fontDialog).destroy()

proc addTextEdit(parent: PVBox, labelText, value: string): PEntry = 
  var label = labelNew("")
  label.setMarkup("<b>" & labelText & "</b>")
  
  var HBox = hboxNew(false, 0)
  parent.packStart(HBox, false, false, 0)
  HBox.show()
  
  HBox.packStart(Label, false, false, 5)
  Label.show()
  
  var EntryHBox = hboxNew(false, 0)
  parent.packStart(EntryHBox, false, false, 0)
  EntryHBox.show()
  
  var entry = entryNew()
  entry.setEditable(True)
  entry.setWidthChars(40)
  entry.setText(value)
  entryHBox.packStart(entry, false, false, 20)
  entry.show()
  result = entry

var
  # General:
  singleInstanceCheckBox: PCheckButton
  restoreTabsCheckBox: PCheckButton
  compileSaveAllCheckBox: PCheckButton
  showCloseOnAllTabsCheckBox: PCheckButton
  # Shortcuts:
  keyCommentLinesEdit: PEntry
  keyDeleteLineEdit: PEntry
  keyDuplicateLinesEdit: PEntry
  keyQuitEdit: PEntry
  keyNewFileEdit: PEntry
  keyOpenFileEdit: PEntry
  keySaveFileEdit: PEntry
  keySaveFileAsEdit: PEntry
  keySaveAllEdit: PEntry
  keyCloseCurrentTabEdit: PEntry
  keyCloseAllTabsEdit: PEntry
  keyFindEdit: PEntry
  keyReplaceEdit: PEntry
  keyFindNextEdit: PEntry
  keyFindPreviousEdit: PEntry
  keyGoToLineEdit: PEntry
  keyGoToDefEdit: PEntry
  keyToggleBottomPanelEdit: PEntry
  keyCompileCurrentEdit: PEntry
  keyCompileRunCurrentEdit: PEntry
  keyCompileProjectEdit: PEntry
  keyCompileRunProjectEdit: PEntry
  keyStopProcessEdit: PEntry
  keyRunCustomCommand1Edit: PEntry
  keyRunCustomCommand2Edit: PEntry
  keyRunCustomCommand3Edit: PEntry
  keyRunCheckEdit: PEntry 
  
  # Tools:
  nimrodEdit, custom1Edit, custom2Edit, custom3Edit: PEntry
  
proc initTools(settingsTabs: PNotebook) =
  var t = vboxNew(false, 5)
  discard settingsTabs.appendPage(t, labelNew("Tools"))
  t.show()
  
  nimrodEdit = addTextEdit(t, "Nimrod", win.globalSettings.nimrodCmd)
  custom1Edit = addTextEdit(t, "Custom Command 1", win.globalSettings.customCmd1)
  custom2Edit = addTextEdit(t, "Custom Command 2", win.globalSettings.customCmd2)
  custom3Edit = addTextEdit(t, "Custom Command 3", win.globalSettings.customCmd3)


proc initFontsColors(settingsTabs: PNotebook) =
  var fontsColorsLabel = labelNew("Fonts and colors")
  var fontsColorsVBox = vboxNew(False, 5)
  discard settingsTabs.appendPage(fontsColorsVBox, fontsColorsLabel)
  fontsColorsVBox.show()
  
  # 'Font' label
  var fontLabelHBox = hboxNew(False, 0)
  fontsColorsVBox.packStart(fontLabelHBox, False, False, 0)
  fontLabelHBox.show()
  
  var fontLabel = labelNew("")
  fontLabel.setMarkup("<b>Font</b>")
  fontLabelHBox.packStart(fontLabel, False, False, 5)
  fontLabel.show()
  
  # Entry (For the font name and size, for example 'monospace 9')
  var fontEntryHBox = hboxNew(False, 0)
  fontsColorsVBox.packStart(fontEntryHBox, False, False, 0)
  fontEntryHBox.show()
  
  var fontEntry = entryNew()
  fontEntry.setEditable(False)
  fontEntry.setText(win.globalSettings.font)
  fontEntryHBox.packStart(fontEntry, False, False, 20)
  fontEntry.show()
  
  # Change font button
  var fontChangeBtn = buttonNew("Change Font")
  discard fontChangeBtn.GSignalConnect("clicked", 
    G_CALLBACK(fontChangeBtn_Clicked), fontEntry)
  fontEntryHBox.packEnd(fontChangeBtn, False, False, 10)
  fontChangeBtn.show()

  # 'Color Scheme' label
  var schemeLabelHBox = hboxNew(False, 0)
  fontsColorsVBox.packStart(schemeLabelHBox, False, False, 0)
  schemeLabelHBox.show()
  
  var schemeLabel = labelNew("")
  schemeLabel.setMarkup("<b>Color Scheme</b>")
  schemeLabelHBox.packStart(schemeLabel, False, False, 5)
  schemeLabel.show()
  
  # Scheme TreeView(Well ListView...)
  var schemeTreeHBox = hboxNew(False, 0)
  fontsColorsVBox.packStart(schemeTreeHBox, True, True, 10)
  schemeTreeHBox.show()
  
  var schemeTree = treeviewNew()
  schemeTree.setHeadersVisible(False) # Make the headers invisible
  var selection = schemeTree.getSelection()
  discard selection.GSignalConnect("changed", 
    G_CALLBACK(schemesTreeView_onChanged), nil)
  var schemeTreeScrolled = scrolledWindowNew(nil, nil)
  # Make the scrollbars invisible by default
  schemeTreeScrolled.setPolicy(POLICY_AUTOMATIC, POLICY_AUTOMATIC)
  # Add a border
  schemeTreeScrolled.setShadowType(SHADOW_IN)
  
  schemeTreeScrolled.add(schemeTree)
  schemeTreeHBox.packStart(schemeTreeScrolled, True, True, 20)
  schemeTreeScrolled.show()
  
  var schemeModel = listStoreNew(2, TYPE_STRING, TYPE_STRING)
  schemeTree.setModel(schemeModel)
  schemeTree.show()
  
  var renderer = cellRendererTextNew()
  var column = treeViewColumnNewWithAttributes("Schemes", 
                                               renderer, "markup", 1, nil)
  discard schemeTree.appendColumn(column)
  # Add all the schemes available, to the TreeView
  schemeTree.addSchemes(schemeModel)

# -- Editor settings
proc showLineNums_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.showLineNumbers = button.getActive()
  # Loop through each tab, and change the setting.
  for i in items(win.Tabs):
    i.sourceView.setShowLineNumbers(win.globalSettings.showLineNumbers)
    
proc hlCurrLine_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.highlightCurrentLine = button.getActive()
  # Loop through each tab, and change the setting.
  for i in items(win.Tabs):
    i.sourceView.setHighlightCurrentLine(
        win.globalSettings.highlightCurrentLine)
    
proc showMargin_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.rightMargin = button.getActive()
  # Loop through each tab, and change the setting.
  for i in items(win.Tabs):
    i.sourceView.setShowRightMargin(win.globalSettings.rightMargin)

proc brackMatch_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.highlightMatchingBrackets = button.getActive()
  # Loop through each tab, and change the setting.
  for i in items(win.Tabs):
    i.buffer.setHighlightMatchingBrackets(
        win.globalSettings.highlightMatchingBrackets)

proc indentWidth_changed(spinbtn: PSpinButton, user_data: pgpointer) =
  win.globalSettings.indentWidth = int32(spinbtn.getValue())
  # Loop through each tab, and change the setting.
  for i in items(win.Tabs):
    i.sourceView.setIndentWidth(win.globalSettings.indentWidth)
  
proc autoIndent_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.autoIndent = button.getActive()
  # Loop through each tab, and change the setting.
  for i in items(win.Tabs):
    i.sourceView.setAutoIndent(win.globalSettings.autoIndent)

proc suggestFeature_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.suggestFeature = button.getActive()

proc showCloseOnAllTabs_Toggled(button: PToggleButton, user_data: pgpointer) =
  win.globalSettings.showCloseOnAllTabs = button.getActive()
  # Loop through each tab, and change the setting.
  for i in 0..len(win.Tabs)-1:
    if win.globalSettings.showCloseOnAllTabs:
      win.Tabs[i].closeBtn.show()
    else:
      if i == win.SourceViewTabs.getCurrentPage():
        win.Tabs[i].closeBtn.show()
      else:
        win.Tabs[i].closeBtn.hide()

proc initEditor(settingsTabs: PNotebook) =
  var editorLabel = labelNew("Editor")
  var editorVBox = vboxNew(False, 5)
  discard settingsTabs.appendPage(editorVBox, editorLabel)
  editorVBox.show()
  
  # indentWidth - SpinButton
  var indentWidthHBox = hboxNew(False, 0)
  editorVBox.packStart(indentWidthHBox, False, False, 5)
  indentWidthHBox.show()
  
  var indentWidthLabel = labelNew("Indent width: ")
  indentWidthHBox.packStart(indentWidthLabel, False, False, 20)
  indentWidthLabel.show()
  
  var indentWidthSpinButton = spinButtonNew(1.0, 24.0, 1.0)
  indentWidthSpinButton.setValue(win.globalSettings.indentWidth.toFloat())
  discard indentWidthSpinButton.GSignalConnect("value-changed", 
    G_CALLBACK(indentWidth_changed), nil)
  indentWidthHBox.packStart(indentWidthSpinButton, False, False, 0)
  indentWidthSpinButton.show()
  
  # showLineNumbers - checkbox
  var showLineNumsHBox = hboxNew(False, 0)
  editorVBox.packStart(showLineNumsHBox, False, False, 0)
  showLineNumsHBox.show()
  
  var showLineNumsCheckBox = checkButtonNew("Show line numbers")
  showLineNumsCheckBox.setActive(win.globalSettings.showLineNumbers)
  discard showLineNumsCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(showLineNums_Toggled), nil)
  showLineNumsHBox.packStart(showLineNumsCheckBox, False, False, 20)
  showLineNumsCheckBox.show()
  
  # highlightCurrentLine - checkbox
  var hlCurrLineHBox = hboxNew(False, 0)
  editorVBox.packStart(hlCurrLineHBox, False, False, 0)
  hlCurrLineHBox.show()
  
  var hlCurrLineCheckBox = checkButtonNew("Highlight selected line")
  hlCurrLineCheckBox.setActive(win.globalSettings.highlightCurrentLine)
  discard hlCurrLineCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(hlCurrLine_Toggled), nil)
  hlCurrLineHBox.packStart(hlCurrLineCheckBox, False, False, 20)
  hlCurrLineCheckBox.show()
  
  # showRightMargin - checkbox
  var showMarginHBox = hboxNew(False, 0)
  editorVBox.packStart(showMarginHBox, False, False, 0)
  showMarginHBox.show()
  
  var showMarginCheckBox = checkButtonNew("Show right margin")
  showMarginCheckBox.setActive(win.globalSettings.rightMargin)
  discard showMarginCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(showMargin_Toggled), nil)
  showMarginHBox.packStart(showMarginCheckBox, False, False, 20)
  showMarginCheckBox.show()
  
  # bracketMatching - checkbox
  var brackMatchHBox = hboxNew(False, 0)
  editorVBox.packStart(brackMatchHBox, False, False, 0)
  brackMatchHBox.show()
  
  var brackMatchCheckBox = checkButtonNew("Enable bracket matching")
  brackMatchCheckBox.setActive(win.globalSettings.highlightMatchingBrackets)
  discard brackMatchCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(brackMatch_Toggled), nil)
  brackMatchHBox.packStart(brackMatchCheckBox, False, False, 20)
  brackMatchCheckBox.show()
  
  # autoIndent - checkbox
  var autoIndentHBox = hboxNew(False, 0)
  editorVBox.packStart(autoIndentHBox, False, False, 0)
  autoIndentHBox.show()
  
  var autoIndentCheckBox = checkButtonNew("Enable auto indent")
  autoIndentCheckBox.setActive(win.globalSettings.autoIndent)
  discard autoIndentCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(autoIndent_Toggled), nil)
  autoIndentHBox.packStart(autoIndentCheckBox, False, False, 20)
  autoIndentCheckBox.show()

  # suggestFeature - checkbox
  var suggestFeatureHBox = hboxNew(False, 0)
  editorVBox.packStart(suggestFeatureHBox, False, False, 0)
  suggestFeatureHBox.show()
  
  var suggestFeatureCheckBox = checkButtonNew("Enable suggest feature")
  suggestFeatureCheckBox.setActive(win.globalSettings.suggestFeature)
  discard suggestFeatureCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(suggestFeature_Toggled), nil)
  suggestFeatureHBox.packStart(suggestFeatureCheckBox, False, False, 20)
  suggestFeatureCheckBox.show()

var
  dialog: gtk2.PWindow
  
proc closeDialog(widget: pWidget, user_data: pgpointer) =
  # General:
  win.globalSettings.restoreTabs = restoreTabsCheckBox.getActive()
  win.globalSettings.singleInstance = singleInstanceCheckBox.getActive()
  win.globalSettings.compileSaveAll = compileSaveAllCheckBox.getActive()
  
  # Shortcuts:
  win.globalSettings.keyQuit = StrToKey($keyQuitEdit.getText())
  win.globalSettings.keyCommentLines = StrToKey($keyCommentLinesEdit.getText())
  win.globalSettings.keyDeleteLine = StrToKey($keyDeleteLineEdit.getText())
  win.globalSettings.keyDuplicateLines = StrToKey($keyDuplicateLinesEdit.getText())
  win.globalSettings.keyNewFile = StrToKey($keyNewFileEdit.getText())
  win.globalSettings.keyOpenFile = StrToKey($keyOpenFileEdit.getText())
  win.globalSettings.keySaveFile = StrToKey($keySaveFileEdit.getText())
  win.globalSettings.keySaveFileAs = StrToKey($keySaveFileAsEdit.getText())
  win.globalSettings.keySaveAll = StrToKey($keySaveAllEdit.getText())
  win.globalSettings.keyCloseCurrentTab = StrToKey($keyCloseCurrentTabEdit.getText())
  win.globalSettings.keyCloseAllTabs = StrToKey($keyCloseAllTabsEdit.getText())
  win.globalSettings.keyFind = StrToKey($keyFindEdit.getText())
  win.globalSettings.keyReplace = StrToKey($keyReplaceEdit.getText())
  win.globalSettings.keyFindNext = StrToKey($keyFindNextEdit.getText())
  win.globalSettings.keyFindPrevious = StrToKey($keyFindPreviousEdit.getText())
  win.globalSettings.keyGoToLine = StrToKey($keyGoToLineEdit.getText())
  win.globalSettings.keyGoToDef = StrToKey($keyGoToDefEdit.getText())
  win.globalSettings.keyToggleBottomPanel = StrToKey($keyToggleBottomPanelEdit.getText())
  win.globalSettings.keyCompileCurrent = StrToKey($keyCompileCurrentEdit.getText())
  win.globalSettings.keyCompileRunCurrent = StrToKey($keyCompileRunCurrentEdit.getText())
  win.globalSettings.keyCompileProject = StrToKey($keyCompileProjectEdit.getText())
  win.globalSettings.keyCompileRunProject = StrToKey($keyCompileRunProjectEdit.getText())
  win.globalSettings.keyStopProcess = StrToKey($keyStopProcessEdit.getText())
  win.globalSettings.keyRunCustomCommand1 = StrToKey($keyRunCustomCommand1Edit.getText())
  win.globalSettings.keyRunCustomCommand2 = StrToKey($keyRunCustomCommand2Edit.getText())
  win.globalSettings.keyRunCustomCommand3 = StrToKey($keyRunCustomCommand3Edit.getText())
  win.globalSettings.keyRunCheck = StrToKey($keyRunCheckEdit.getText())
    
  # Tools:
  win.globalSettings.nimrodCmd = $nimrodEdit.getText()
  win.globalSettings.customCmd1 = $custom1Edit.getText()
  win.globalSettings.customCmd2 = $custom2Edit.getText()
  win.globalSettings.customCmd3 = $custom3Edit.getText()
  
  gtk2.PObject(dialog).destroy()
  
proc addCheckBox(parent: PVBox, labelText: string, value: bool): PCheckButton = 
  var Box = hboxNew(false, 0)
  parent.packStart(Box, false, false, 0)
  Box.show()
  var CheckBox = checkButtonNew(labelText)
  CheckBox.setActive(value)
  Box.packStart(CheckBox, false, false, 20)
  CheckBox.show()
  Result = CheckBox
  
proc initGeneral(settingsTabs: PNotebook) =
  var box = vboxNew(false, 5)
  discard settingsTabs.appendPage(box, labelNew("General"))
  box.show()
  
  singleInstanceCheckBox = addCheckBox(box, "Single instance", win.globalSettings.singleInstance)
  
  compileSaveAllCheckBox = addCheckBox(box, "Save all on compile", win.globalSettings.compileSaveAll)
  
  restoreTabsCheckBox = addCheckBox(box, "Restore tabs on load", win.globalSettings.restoreTabs)
  
  showCloseOnAllTabsCheckBox = addCheckBox(box, "Show close button on all tabs", win.globalSettings.showCloseOnAllTabs)
  discard showCloseOnAllTabsCheckBox.GSignalConnect("toggled", 
    G_CALLBACK(showCloseOnAllTabs_Toggled), nil)

proc removeDuplicateShortcut(entrySender: PEntry, entryToCheck: PEntry) = 
  if entrySender != entryToCheck and $entrySender.getText() == $entryToCheck.getText():
    entryToCheck.setText("")
    
proc entryKeyRelease(entry: PEntry, EventKey: PEventKey) {.cdecl.} =
  if EventKey.keyval == KEY_Delete:
    entry.setText("")
  elif EventKey.keyval < 65505:
    entry.setText(KeyToStr(TShortcutKey(keyval: EventKey.keyval, state: EventKey.state)))
    removeDuplicateShortcut(entry, keyCommentLinesEdit)
    removeDuplicateShortcut(entry, keyDeleteLineEdit)
    removeDuplicateShortcut(entry, keyDuplicateLinesEdit)
    removeDuplicateShortcut(entry, keyQuitEdit)
    removeDuplicateShortcut(entry, keyNewFileEdit)
    removeDuplicateShortcut(entry, keyOpenFileEdit)
    removeDuplicateShortcut(entry, keySaveFileEdit)
    removeDuplicateShortcut(entry, keySaveFileAsEdit)
    removeDuplicateShortcut(entry, keySaveAllEdit)
    removeDuplicateShortcut(entry, keyCloseCurrentTabEdit)
    removeDuplicateShortcut(entry, keyCloseAllTabsEdit)
    removeDuplicateShortcut(entry, keyFindEdit)
    removeDuplicateShortcut(entry, keyReplaceEdit)
    removeDuplicateShortcut(entry, keyFindNextEdit)
    removeDuplicateShortcut(entry, keyFindPreviousEdit)
    removeDuplicateShortcut(entry, keyGoToLineEdit)
    removeDuplicateShortcut(entry, keyGoToDefEdit)
    removeDuplicateShortcut(entry, keyToggleBottomPanelEdit)
    removeDuplicateShortcut(entry, keyCompileCurrentEdit)
    removeDuplicateShortcut(entry, keyCompileRunCurrentEdit)
    removeDuplicateShortcut(entry, keyCompileProjectEdit)
    removeDuplicateShortcut(entry, keyCompileRunProjectEdit)
    removeDuplicateShortcut(entry, keyStopProcessEdit)
    removeDuplicateShortcut(entry, keyRunCustomCommand1Edit)
    removeDuplicateShortcut(entry, keyRunCustomCommand2Edit)
    removeDuplicateShortcut(entry, keyRunCustomCommand3Edit)
    removeDuplicateShortcut(entry, keyRunCheckEdit)
        
proc addKeyEdit(parent: PVBox, labelText: string, key: TShortcutKey): PEntry = 
  var HBox = hboxNew(false, 0)
  parent.packStart(HBox, false, false, 0)
  HBox.show()
 
  var Label = labelNew(labelText)
  Label.setWidthChars(27)
  Label.setAlignment(0, 0.5) 
  HBox.packStart(Label, false, false, 5)
  Label.show()
    
  var entry = entryNew()
  entry.setEditable(false)
  entry.setWidthChars(16)
  entry.setText(KeyToStr(key))
  discard entry.signalConnect("key-release-event", SIGNAL_FUNC(entryKeyRelease), nil)
  HBox.packStart(entry, false, false, 5)
  entry.show()
  result = entry
  
proc initShortcuts(settingsTabs: PNotebook) =
  var VBox = vboxNew(false, 5)
  discard settingsTabs.appendPage(VBox, labelNew("Shortcuts"))
  VBox.show()
  
  var HBox = hboxNew(false, 30)
  VBox.packStart(HBox, false, false, 5)
  HBox.show()

  var hint = labelNew("Use the Delete button to clear a shortbut. Changes will be active after restart")
  hint.setAlignment(0, 0.5) 
  hint.show()
  var Box2 = hboxNew(false, 0)
  VBox.packStart(Box2, false, false, 0)
  Box2.show()
  Box2.packStart(hint, false, false, 10)
    
  VBox = vboxNew(false, 5)
  HBox.packStart(VBox, false, false, 5)
  VBox.show()
  
  keyCommentLinesEdit = addKeyEdit(VBox, "Comment lines", win.globalSettings.keyCommentLines)
  keyDeleteLineEdit = addKeyEdit(VBox, "Delete line", win.globalSettings.keyDeleteLine)
  keyDuplicateLinesEdit = addKeyEdit(VBox, "Duplicate lines", win.globalSettings.keyDuplicateLines)
  keyNewFileEdit = addKeyEdit(VBox, "New file", win.globalSettings.keyNewFile)
  keyOpenFileEdit = addKeyEdit(VBox, "Open file", win.globalSettings.keyOpenFile)
  keySaveFileEdit = addKeyEdit(VBox, "Save file", win.globalSettings.keySaveFile)
  keySaveFileAsEdit = addKeyEdit(VBox, "Save file as", win.globalSettings.keySaveFileAs)
  keySaveAllEdit = addKeyEdit(VBox, "Save all", win.globalSettings.keySaveAll)
  keyCloseCurrentTabEdit = addKeyEdit(VBox, "Close current tab", win.globalSettings.keyCloseCurrentTab)
  keyCloseAllTabsEdit = addKeyEdit(VBox, "Close all tabs", win.globalSettings.keyCloseAllTabs)
  keyFindEdit = addKeyEdit(VBox, "Find", win.globalSettings.keyFind)
  keyReplaceEdit = addKeyEdit(VBox, "Find and replace", win.globalSettings.keyReplace)
  keyFindNextEdit = addKeyEdit(VBox, "Find next", win.globalSettings.keyFindNext)
  keyFindPreviousEdit = addKeyEdit(VBox, "Find previous", win.globalSettings.keyFindPrevious)
 
  VBox = vboxNew(false, 5)
  HBox.packStart(VBox, false, false, 5)
  VBox.show()

  keyGoToLineEdit = addKeyEdit(VBox, "Go to line", win.globalSettings.keyGoToLine)
  keyGoToDefEdit = addKeyEdit(VBox, "Go to definition under cursor", win.globalSettings.keyGoToDef)   
  keyQuitEdit = addKeyEdit(VBox, "Quit", win.globalSettings.keyQuit)
  keyToggleBottomPanelEdit = addKeyEdit(VBox, "Show/hide bottom panel", win.globalSettings.keyToggleBottomPanel)
  keyCompileCurrentEdit = addKeyEdit(VBox, "Compile current file", win.globalSettings.keyCompileCurrent)
  keyCompileRunCurrentEdit = addKeyEdit(VBox, "Compile & run current file", win.globalSettings.keyCompileRunCurrent)
  keyCompileProjectEdit = addKeyEdit(VBox, "Compile project", win.globalSettings.keyCompileProject)
  keyCompileRunProjectEdit = addKeyEdit(VBox, "Compile & run project", win.globalSettings.keyCompileRunProject)
  keyStopProcessEdit = addKeyEdit(VBox, "Terminate running process", win.globalSettings.keyStopProcess)
  keyRunCustomCommand1Edit = addKeyEdit(VBox, "Run custom command 1", win.globalSettings.keyRunCustomCommand1)
  keyRunCustomCommand2Edit = addKeyEdit(VBox, "Run custom command 2", win.globalSettings.keyRunCustomCommand2)
  keyRunCustomCommand3Edit = addKeyEdit(VBox, "Run custom command 3", win.globalSettings.keyRunCustomCommand3)
  keyRunCheckEdit = addKeyEdit(VBox, "Check", win.globalSettings.keyRunCheck)
          
proc showSettings*(aWin: var utils.MainWin) =
  win = addr(aWin)  # This has to be a pointer
                    # Because i need the settings to be changed
                    # in aporia.nim not in here.

  dialog = windowNew(gtk2.WINDOW_TOPLEVEL)
  dialog.setDefaultSize(740, 530)
  dialog.setSizeRequest(740, 530)
  dialog.setTransientFor(win.w)
  dialog.setTitle("Settings")
  dialog.setTypeHint(WINDOW_TYPE_HINT_DIALOG)

  var contentArea = vboxNew(False, 0)
  dialog.add(contentArea)
  contentArea.show()
  
  var sHBox = hboxNew(False, 0) # Just used for some padding
  contentArea.packStart(sHBox, True, True, 10)
  sHBox.show()
  
  var tabsVBox = vboxNew(False, 0) # So that HSeperator is close to the tabs
  sHBox.packStart(tabsVBox, True, True, 10)
  tabsVBox.show()
  
  var settingsTabs = notebookNew()
  tabsVBox.packStart(settingsTabs, True, True, 0)
  settingsTabs.show()
  
  var tabsBottomLine = hSeparatorNew()
  tabsVBox.packStart(tabsBottomLine, False, False, 0)
  tabsBottomLine.show()
  
  # HBox for the close button
  var bottomHBox = hboxNew(False, 0)
  contentArea.packStart(bottomHBox, False, False, 5)
  bottomHBox.show()
  
  var closeBtn = buttonNewWithMnemonic("_Close")
  discard closeBtn.GSignalConnect("clicked", 
    G_CALLBACK(closeDialog), nil)
  bottomHBox.packEnd(closeBtn, False, False, 10)
  # Change the size of the close button
  var rq1: TRequisition 
  closeBtn.sizeRequest(addr(rq1))
  closeBtn.set_size_request(rq1.width + 10, rq1.height + 4)
  closeBtn.show()
  
  initGeneral(settingsTabs)
  initEditor(settingsTabs)
  initFontsColors(settingsTabs)
  initShortcuts(settingsTabs)
  initTools(settingsTabs)
  
  dialog.show()
