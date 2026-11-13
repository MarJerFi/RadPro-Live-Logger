program radpro_live_logger;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, tachartlazaruspkg, anchordockpkg, Unit1, LazSerialPort,
  uDarkStyleParams, uMetaDarkStyle, uDarkStyleSchemes
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}

// Automatycznie włącza ciemny motyw, jeśli Windows jest w trybie Dark Mode
  PreferredAppMode := pamAllowDark;
  uMetaDarkStyle.ApplyMetaDarkStyle(DefaultDark);

  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

