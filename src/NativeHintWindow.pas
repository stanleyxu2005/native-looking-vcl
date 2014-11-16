(**
 * $Id: NativeHintWindow.pas 808 2014-05-07 06:07:54Z QXu $
 *
 * Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either
 * express or implied. See the License for the specific language governing rights and limitations under the License.
 *)

unit NativeHintWindow;

(**
 * KNOWN ISSUE:
 *  The width of tooltip window border is incorrect. It should be 7px (not 11px) in Windows 7.
 *)

interface

uses
  Winapi.Windows;

  /// <summary>Displays the hint window.</summary>
  procedure NativeActivateHint(const Text: string; const PopupPoint: TPoint);

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.SysUtils,
  System.Types,
  Winapi.CommCtrl,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.Forms,
  Cromis.Detours,
  dui.metrics.TextExtent;

type
  THintWindowOverride = class(THintWindow)
  private
    FTooltipWindow: HWND;
    FWindowTopLeftCorner: TPoint;
    /// <summary>Removes existing hint window if the current *short* hint is not specified.</summary>
    procedure CheckDestroyTooltipWindow(Sender: TObject);
  protected
    // BLOCK-BEGIN: Disable the following procedures.
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure NCPaint(DC: HDC); override;
    procedure WMPrint(var Message: TMessage); message WM_PRINT;
    procedure WMNCPaint(var Message: TMessage); message WM_NCPAINT;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    // BLOCK-END
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ReleaseHandle;
    procedure ActivateHint(Rect: TRect; const AHint: string); override;
    function CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect; override;
  private
    /// <exception cref="EOSError">Cursor pointer position information is not available.</exception>
    class function RequireNotClipped(TooltipWindow: HWND; const PopupPoint: TPoint; const Text: string): TPoint; static;
    class function CalcTooltipWindowExtent(TooltipWindow: HWND; const Text: string): TSize; static;
    /// <exception cref="EOSError">Failed to obtain text extent.</exception>
    class function CalcHintTextRect(MaxWidth: Integer; const AHint: string): TRect; static;
    class function InternalActivateHint(const ExpectedPos: TPoint; const Text: string): THandle; static;
  end;

var
  GHintWindowInstances: TList<THintWindowOverride>;

constructor THintWindowOverride.Create(AOwner: TComponent);
begin
  inherited;

  // Tooltip constants are recommanded by Microsoft (http://msdn2.microsoft.com/en-us/library/aa511495.aspx)
  Application.HintPause := {TOOLTIP_INITIAL_TIMEOUT=}500;
  Application.HintShortPause := {TOOLTIP_RESHOW_TIMEOUT=}100;
  Application.HintHidePause := {TOOLTIP_REMOVAL_TIMEOUT=}5000;
  Application.OnHint := CheckDestroyTooltipWindow;

  GHintWindowInstances.Add(Self);
end;

destructor THintWindowOverride.Destroy;
begin
  GHintWindowInstances.Remove(Self);

  inherited;
end;

procedure THintWindowOverride.CreateParams(var Params: TCreateParams);
begin
  // override the method, because we do not intend to draw anything on the internal Canvas
end;

procedure THintWindowOverride.Paint;
begin
  // override the method, because we do not intend to draw anything on the internal Canvas
end;

procedure THintWindowOverride.NCPaint(DC: HDC);
begin
  // override the method, because we do not intend to draw anything on the internal Canvas
end;

procedure THintWindowOverride.WMPrint(var Message: TMessage);
begin
  // override the method, because we do not intend to draw anything on the internal Canvas
end;

procedure THintWindowOverride.WMNCPaint(var Message: TMessage);
begin
  // override the method, because we do not intend to draw anything on the internal Canvas
end;

procedure THintWindowOverride.CMTextChanged(var Message: TMessage);
begin
  // override the method, because we do not intend to draw anything on the internal Canvas
end;

procedure THintWindowOverride.CheckDestroyTooltipWindow(Sender: TObject);
var
  CurrentHint: string;
begin
  CurrentHint := GetShortHint(Application.Hint);
  if (CurrentHint = '') or (Trim(CurrentHint) = '') then
    ReleaseHandle;
end;

procedure THintWindowOverride.ReleaseHandle;
begin
  if IsWindow(FTooltipWindow) then
    DestroyWindow(FTooltipWindow);
end;

procedure THintWindowOverride.ActivateHint(Rect: TRect; const AHint: string);
begin
  if IsWindow(FTooltipWindow) then
  begin
    if ((Rect.Top = FWindowTopLeftCorner.Y) and (Rect.Left = FWindowTopLeftCorner.X)) and (AHint = Caption) then
      Exit // To avoid the hint to be be drawn multiple times
    else
      DestroyWindow(FTooltipWindow);
  end;

  Caption := AHint;
  FTooltipWindow := InternalActivateHint(Rect.TopLeft, AHint);
  if FTooltipWindow > 0 then
    FWindowTopLeftCorner := Rect.TopLeft;
end;

function THintWindowOverride.CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect;
begin
  try
    Result := CalcHintTextRect(MaxWidth, AHint);
  except
    on EOSError do
      Result := inherited; // note that the result is somehow incorrect
  end;
end;

class function THintWindowOverride.RequireNotClipped(TooltipWindow: HWND; const PopupPoint: TPoint;
  const Text: string): TPoint;
var
  Monitor: TMonitor;
  VisibleRect: TRect;
  WindowExtent: TSize;
  CursorPos: TPoint;
begin
  assert(TooltipWindow > 0);

  Monitor := Screen.MonitorFromPoint(PopupPoint);
  if Monitor <> nil then
    VisibleRect := Monitor.BoundsRect
  else
    VisibleRect := Screen.DesktopRect;

  WindowExtent := CalcTooltipWindowExtent(TooltipWindow, Text);
  Result := PopupPoint;

  // Correct the y-position of the hint window, when it is partially out of the screen.
  if Result.Y + WindowExtent.cy >= VisibleRect.Bottom then
  begin
    if not GetCursorPos(CursorPos) then
      RaiseLastOSError;
    Result.Y := CursorPos.Y - WindowExtent.cy;
  end;
  Result.Y := Max(Result.Y, VisibleRect.Top);

  // Correct the x-position of the hint window, when it is partially out of the screen.
  if Result.X + WindowExtent.cx >= VisibleRect.Right then
    Result.X := VisibleRect.Right - WindowExtent.cx;
  Result.X := Max(Result.X, VisibleRect.Left);

  // Additionally make sure the tooltip width will not exceed the available range
  SendMessage(TooltipWindow, TTM_SETMAXTIPWIDTH, 0, VisibleRect.Right - Result.X);
end;

class function THintWindowOverride.CalcTooltipWindowExtent(TooltipWindow: HWND; const Text: string): TSize;
var
  BorderRect: TRect;
  TextRect: TRect;
begin
  assert(TooltipWindow > 0);

  // Calculate the width and height of hint window border
  BorderRect := Rect(0, 0, 0, 0);
  SendMessage(TooltipWindow, TTM_ADJUSTRECT, {GetHintWindowBorderRectangle=}WPARAM(TRUE), LPARAM(@BorderRect));

  // Calculate the width and height of tooltip text (no text wrapping consideration)
  TextRect := CalcHintTextRect(System.MaxInt, Text);

  Result.cx := RectWidth(TextRect) + RectWidth(BorderRect) * 2;
  Result.cy := RectHeight(TextRect) + RectHeight(BorderRect) * 2;
end;

class function THintWindowOverride.InternalActivateHint(const ExpectedPos: TPoint; const Text: string): THandle;
var
  ActualPos: TPoint;
  Tooltip: TOOLINFO;
begin
  Result := CreateWindow(TOOLTIPS_CLASS, nil, WS_POPUP or TTS_NOPREFIX or TTS_ALWAYSTIP, Integer(CW_USEDEFAULT),
    Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT), 0, 0, HInstance, nil);
  if Result = 0 then
    Exit;

  SetWindowPos(Result, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOACTIVATE or SWP_NOMOVE or SWP_NOSIZE);

  try
    ActualPos := RequireNotClipped(Result, Point(ExpectedPos.X, ExpectedPos.Y + 1), Text);
  except
    on EOSError do
      Exit;
  end;

  ZeroMemory(@Tooltip, SizeOf(Tooltip));
  Tooltip.cbSize := SizeOf(Tooltip);
  Tooltip.hwnd := WindowFromPoint(ExpectedPos);
  Tooltip.lpszText := PChar(Text);
  Tooltip.uFlags := TTF_TRANSPARENT or TTF_SUBCLASS or TTF_TRACK or TTF_ABSOLUTE;

  SendMessage(Result, TTM_ADDTOOL, 0, LPARAM(@Tooltip));
  SendMessage(Result, TTM_TRACKPOSITION, 0, PointToLParam(ActualPos));
  SendMessage(Result, TTM_TRACKACTIVATE, {ActivateTracking=}WPARAM(TRUE), LPARAM(@Tooltip));
end;

class function THintWindowOverride.CalcHintTextRect(MaxWidth: Integer; const AHint: string): TRect;
var
  TextExtent: TSize;
begin
  TextExtent := TTextExtent.ComputeMultiLineTextExtent(AHint, Screen.HintFont.Handle);
  if TextExtent.cx > MaxWidth then
    Result := Rect(0, 0, MaxWidth, TextExtent.cy * Ceil(TextExtent.cx / MaxWidth))
  else
    Result := Rect(0, 0, TextExtent.cx, TextExtent.cy);
end;

procedure NativeActivateHint(const Text: string; const PopupPoint: TPoint);
begin
  assert(Text <> '');

  if GHintWindowInstances.Count = 0 then
  begin
    // Trick: to let the global Application instance to create an instance of HintWindowClass.
    Application.ShowHint := False;
    Application.ShowHint := True;
  end;

  if GHintWindowInstances.Count > 0 then
  begin
    Application.HideHint;
    // Reuse the first hint window instance to show the tooltip
    GHintWindowInstances[0].ActivateHint(Rect(PopupPoint.X, PopupPoint.Y, 0, 0), Text);
  end;
end;

{ RTL patch }

var
  TrampolineHideHint: procedure = nil;

procedure InterceptHideHint;
var
  HintWindow: THintWindow;
begin
  for HintWindow in GHintWindowInstances do
    try
      HintWindow.ReleaseHandle;
    except
    end;
end;

initialization

GHintWindowInstances := TList<THintWindowOverride>.Create;
HintWindowClass := THintWindowOverride;
TrampolineHideHint := InterceptCreate(@TApplication.HideHint, @InterceptHideHint);

finalization

InterceptRemove(@TrampolineHideHint, @InterceptHideHint);
GHintWindowInstances.Free;
GHintWindowInstances := nil;

end.
