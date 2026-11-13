unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LazSerial, LazSynaSer, TAGraph, TASeries, TAChartUtils, TASources;

type
  // Tracks which command was sent last so responses are never mixed up
  TQueryType = (qtNone, qtSensitivity, qtBattery, qtRate);

  // Structure for storing a single measurement in RAM buffer
  TLogRecord = record
    Timestamp: TDateTime;
    CPM: Double;
    DoseRate: Double;
    BatteryV: Double;
  end;

  { TForm1 }

  TForm1 = class(TForm)
    ButtonClearBuffer: TButton;
    ButtonConnect: TButton;
    ButtonRefresh: TButton;
    ButtonSaveBuffer: TButton;
    ButtonSelectFile: TButton;
    Chart1: TChart;
    Chart1LineSeries1: TLineSeries;
    CheckBoxAutoSave: TCheckBox;
    ComboBoxInterval: TComboBox;
    ComboBoxPort: TComboBox;
    EditFactor: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    LabelBattery: TLabel;
    LabelBufferCount: TLabel;
    LabelCPM: TLabel;
    LabelDose: TLabel;
    LazSerial1: TLazSerial;
    ListChartSource1: TListChartSource;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel7: TPanel;
    Panel8: TPanel;
    Panel9: TPanel;
    SaveDialog1: TSaveDialog;
    Timer1: TTimer;
    procedure ButtonClearBufferClick(Sender: TObject);
    procedure ButtonConnectClick(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure ButtonSaveBufferClick(Sender: TObject);
    procedure ButtonSelectFileClick(Sender: TObject);
    procedure ComboBoxIntervalChange(Sender: TObject);
    procedure FormClose(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure LazSerial1RxData(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    RxBuffer: string;
    LogBuffer: array of TLogRecord;
    AutoSaveFilePath: string;
    LastBatteryVoltage: Double;
    PollCounter: Integer;
    CurrentQuery: TQueryType;
    const
      MAX_BUFFER_SIZE = 100000; // Safe RAM limit (~27 hours at 1s interval)
      DEFAULT_CONVERSION_FACTOR = 108.345; // Fallback if device query fails
    function GetConversionFactor: Double;
    procedure SendCommand(QueryType: TQueryType; const Cmd: string);
    procedure RefreshSerialPorts;
    procedure ProcessResponseLine(const Line: string);
    procedure AddRecordToBuffer(CPMVal, DoseVal, BattVal: Double);
    procedure AppendSingleRecordToCSV(const FileName: string; const Rec: TLogRecord);
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin

  LastBatteryVoltage := 0.0;
  PollCounter := 0;
  CurrentQuery := qtNone;
  AutoSaveFilePath := ExtractFilePath(ParamStr(0)) + 'radpro_log.csv';
  EditFactor.Text := '108.345';

  // Populate polling intervals
  ComboBoxInterval.Style := csDropDownList;
  ComboBoxInterval.Items.Add('0.5 sec');
  ComboBoxInterval.Items.Add('1 sec');
  ComboBoxInterval.Items.Add('2 sec');
  ComboBoxInterval.Items.Add('5 sec');
  ComboBoxInterval.Items.Add('10 sec');
  ComboBoxInterval.Items.Add('1 min');
  ComboBoxInterval.Items.Add('5 min');
  ComboBoxInterval.Items.Add('15 min');
  ComboBoxInterval.Items.Add('1 hour');
  ComboBoxInterval.ItemIndex := 1; // Default: 1 sec
  Timer1.Interval := 1000;

  // Configure Chart appearance & vertical Date/Time labels on X-axis
  Chart1.Title.Text.Text := 'Radiation Dose Rate (uSv/h)';
  Chart1.Title.Visible := True;
  Chart1.Legend.Visible := False;

  Chart1LineSeries1.SeriesColor := clRed;
  Chart1LineSeries1.Source := ListChartSource1;


  // Test points (remove before final build)
//  ListChartSource1.Add(0, 25.4, '11.12 13:35:00');
//  ListChartSource1.Add(1, 28.1, '11.12 13:35:01');

  RefreshSerialPorts;
end;

// Helper procedure to send command and remember what we asked for
procedure TForm1.SendCommand(QueryType: TQueryType; const Cmd: string);
begin
  if LazSerial1.Active then
  begin
    CurrentQuery := QueryType;
    LazSerial1.WriteData(Cmd + #13#10);
  end;
end;

// Safely reads the tube conversion factor from EditFactor (supports both '.' and ',')
function TForm1.GetConversionFactor: Double;
var
  CleanText: string;
  Val: Double;
  FS: TFormatSettings;
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  CleanText := StringReplace(Trim(EditFactor.Text), ',', '.', [rfReplaceAll]);
  if TryStrToFloat(CleanText, Val, FS) and (Val > 0.001) then
    Result := Val
  else
    Result := DEFAULT_CONVERSION_FACTOR;
end;

procedure TForm1.RefreshSerialPorts;
begin
  ComboBoxPort.Items.CommaText := GetSerialPortNames;
  if ComboBoxPort.Items.Count > 0 then
    ComboBoxPort.ItemIndex := 0;
end;

procedure TForm1.ButtonRefreshClick(Sender: TObject);
begin
  RefreshSerialPorts;
end;

procedure TForm1.ComboBoxIntervalChange(Sender: TObject);
var
  WasEnabled: Boolean;
begin
  WasEnabled := Timer1.Enabled;
  Timer1.Enabled := False;

  case ComboBoxInterval.ItemIndex of
    0: Timer1.Interval := 500;      // 0.5 sec
    1: Timer1.Interval := 1000;     // 1 sec
    2: Timer1.Interval := 2000;     // 2 sec
    3: Timer1.Interval := 5000;     // 5 sec
    4: Timer1.Interval := 10000;    // 10 sec
    5: Timer1.Interval := 60000;    // 1 min
    6: Timer1.Interval := 300000;   // 5 min
    7: Timer1.Interval := 900000;   // 15 min
    8: Timer1.Interval := 3600000;  // 1 hour
  end;

  Timer1.Enabled := WasEnabled;
end;

procedure TForm1.FormClose(Sender: TObject);
begin
  Timer1.Enabled := False;
  if LazSerial1.Active then
    LazSerial1.Close;
end;

procedure TForm1.ButtonConnectClick(Sender: TObject);
begin
  if not LazSerial1.Active then
  begin
    if ComboBoxPort.Text = '' then
    begin
      ShowMessage('Please select a COM port first.');
      Exit;
    end;

    LazSerial1.Device := ComboBoxPort.Text;
    try
      RxBuffer := '';
      PollCounter := 0;
      LazSerial1.Open;
      ButtonConnect.Caption := 'Disconnect';
      ComboBoxPort.Enabled := False;

      // Step 1 on connect: Ask device for its configured tube sensitivity
      SendCommand(qtSensitivity, 'GET tubeSensitivity');
      Timer1.Enabled := True;
    except
      on E: Exception do
        ShowMessage('Connection error: ' + E.Message);
    end;
  end
  else
  begin
    Timer1.Enabled := False;
    CurrentQuery := qtNone;
    LazSerial1.Close;
    ButtonConnect.Caption := 'Connect';
    ComboBoxPort.Enabled := True;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  if not LazSerial1.Active then Exit;

  // Query battery voltage every 10th cycle, otherwise query radiation rate
  Inc(PollCounter);
  if PollCounter >= 10 then
  begin
    PollCounter := 0;
    SendCommand(qtBattery, 'GET deviceBatteryVoltage');
  end
  else
  begin
    SendCommand(qtRate, 'GET tubeRate');
  end;
end;

procedure TForm1.LazSerial1RxData(Sender: TObject);
var
  EnterPos: Integer;
  Line: string;
begin
  RxBuffer := RxBuffer + LazSerial1.ReadData;

  EnterPos := Pos(#10, RxBuffer);
  while EnterPos > 0 do
  begin
    Line := Trim(Copy(RxBuffer, 1, EnterPos - 1));
    Delete(RxBuffer, 1, EnterPos);

    if Line <> '' then
      ProcessResponseLine(Line);

    EnterPos := Pos(#10, RxBuffer);
  end;
end;

procedure TForm1.ProcessResponseLine(const Line: string);
var
  CleanValueStr, TimeLabel: string;
  NumericVal, DoseVal, Factor: Double;
  FS: TFormatSettings;
begin
  // RadPro replies start with "OK "
  if Copy(Line, 1, 3) <> 'OK ' then Exit;

  CleanValueStr := Trim(Copy(Line, 4, Length(Line)));
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  if not TryStrToFloat(CleanValueStr, NumericVal, FS) then Exit;

  case CurrentQuery of
    qtSensitivity:
      begin
        // Automatically update EditFactor with value read from device
        if NumericVal > 0.001 then
          EditFactor.Text := Format('%.2f', [NumericVal], FS);
        // Step 2 on connect: Immediately query battery voltage next
        SendCommand(qtBattery, 'GET deviceBatteryVoltage');
      end;

    qtBattery:
      begin
        LastBatteryVoltage := NumericVal;
        LabelBattery.Caption := Format('Battery: %.2f V', [LastBatteryVoltage]);
        // Immediately follow up with first rate measurement
        SendCommand(qtRate, 'GET tubeRate');
      end;

    qtRate:
      begin
        Factor := GetConversionFactor;
        DoseVal := NumericVal / Factor;

        LabelCPM.Caption := Format('%.2f CPM', [NumericVal]);
        LabelDose.Caption := Format('%.3f uSv/h', [DoseVal]);

        // Format date and time for X-axis label
        TimeLabel := FormatDateTime('mm.dd hh:nn:ss', Now);

        // Add point directly to ListChartSource1
        ListChartSource1.Add(ListChartSource1.Count, DoseVal, TimeLabel);

        // Scroll X-axis window to show the latest 60 readings
        if ListChartSource1.Count > 60 then
        begin
          Chart1.BottomAxis.Range.UseMin := True;
          Chart1.BottomAxis.Range.UseMax := True;
          Chart1.BottomAxis.Range.Min := ListChartSource1.Count - 60;
          Chart1.BottomAxis.Range.Max := ListChartSource1.Count - 1;
        end;

        // Save to RAM buffer (and optionally to CSV)
        AddRecordToBuffer(NumericVal, DoseVal, LastBatteryVoltage);
      end;
  end;
end;

procedure TForm1.AddRecordToBuffer(CPMVal, DoseVal, BattVal: Double);
var
  NewIdx: Integer;
  NewRec: TLogRecord;
begin
  NewRec.Timestamp := Now;
  NewRec.CPM := CPMVal;
  NewRec.DoseRate := DoseVal;
  NewRec.BatteryV := BattVal;

  // Store in RAM if under limit
  if Length(LogBuffer) < MAX_BUFFER_SIZE then
  begin
    NewIdx := Length(LogBuffer);
    SetLength(LogBuffer, NewIdx + 1);
    LogBuffer[NewIdx] := NewRec;
    LabelBufferCount.Caption := Format('Buffer: %d records', [Length(LogBuffer)]);
  end;

  // If Auto-save checkbox is checked, append immediately to CSV
  if CheckBoxAutoSave.Checked then
  AppendSingleRecordToCSV(AutoSaveFilePath, NewRec);
  end;
  procedure TForm1.AppendSingleRecordToCSV(const FileName: string; const Rec: TLogRecord);
  var
  F: TextFile;
  FileExisted: Boolean;
  FS: TFormatSettings;
  begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FileExisted := FileExists(FileName);
  AssignFile(F, FileName);
  try
  if FileExisted then
  Append(F)
  else
  begin
  Rewrite(F);
  Writeln(F, Format('Timestamp,CPM,Dose_uSv_h (Factor=%.2f),Battery_V', [GetConversionFactor], FS));
  end;
  Writeln(F, Format('%s,%.2f,%.4f,%.2f', [
  FormatDateTime('yyyy-mm-dd hh:nn:ss', Rec.Timestamp),
  Rec.CPM,
  Rec.DoseRate,
  Rec.BatteryV
  ], FS));
  finally
  CloseFile(F);
  end;
  end;
  procedure TForm1.ButtonSelectFileClick(Sender: TObject);
  begin
  SaveDialog1.FileName := AutoSaveFilePath;
  if SaveDialog1.Execute then
  begin
  AutoSaveFilePath := SaveDialog1.FileName;
  CheckBoxAutoSave.Caption := 'Auto-save: ' + ExtractFileName(AutoSaveFilePath);
  end;
  end;
  procedure TForm1.ButtonSaveBufferClick(Sender: TObject);
  var
  F: TextFile;
  i: Integer;
  FS: TFormatSettings;
  begin
  if Length(LogBuffer) = 0 then
  begin
  ShowMessage('Buffer is empty. Nothing to save.');
  Exit;
  end;
  SaveDialog1.FileName := 'radpro_export_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.csv';
  if not SaveDialog1.Execute then Exit;
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  AssignFile(F, SaveDialog1.FileName);
  try
  Rewrite(F);
  Writeln(F, Format('Timestamp,CPM,Dose_uSv_h (Factor=%.2f),Battery_V', [GetConversionFactor], FS));
  for i := 0 to High(LogBuffer) do
  begin
  Writeln(F, Format('%s,%.2f,%.4f,%.2f', [
  FormatDateTime('yyyy-mm-dd hh:nn:ss', LogBuffer[i].Timestamp),
  LogBuffer[i].CPM,
  LogBuffer[i].DoseRate,
  LogBuffer[i].BatteryV
  ], FS));
  end;
  ShowMessage(Format('Successfully exported %d records.', [Length(LogBuffer)]));
  finally
  CloseFile(F);
  end;
  end;
  procedure TForm1.ButtonClearBufferClick(Sender: TObject);
  begin
  SetLength(LogBuffer, 0);
  ListChartSource1.Clear;
  Chart1.BottomAxis.Range.UseMin := False;
  Chart1.BottomAxis.Range.UseMax := False;
  LabelBufferCount.Caption := 'Buffer: 0 records';
  end;
  end.
