(**
 * Software distributed under the MIT License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either
 * express or implied. See the License for the specific language governing rights and limitations under the License.
 *)
unit NativeShortCut;

interface

implementation

uses
  System.Classes,
  System.StrUtils,
  Vcl.Menus,
  Winapi.Windows,
  Cromis.Detours { http://www.cromis.net/blog/downloads/cromis-ipc/ };

{ RTL patch }

var
  TrampolineShortCutToText: function(ShortCut: TShortCut): string = nil;

function InterceptShortCutToText(ShortCut: TShortCut): string;
(**
 * This function replaces the following shortcuts
 *    "Ctrl++" ->  "Ctrl +"     "Ctrl+-" ->  "Ctrl -"
 *   "Shift++" -> "Shift +"    "Shift+-" -> "Shift -"
 *     "Alt++" ->   "Alt +"      "Alt+-" ->   "Alt -"
 *)
begin
  Result := TrampolineShortCutToText(ShortCut);

  case LoByte(Word(ShortCut)) of
    VK_OEM_PLUS, VK_ADD:
      Result := ReplaceStr(Result, '++', ' +');

    VK_OEM_MINUS, VK_SUBTRACT:
      Result := ReplaceStr(Result, '+-', ' -');
  end;
end;

initialization

TrampolineShortCutToText := InterceptCreate(@ShortCutToText, @InterceptShortCutToText);

finalization

InterceptRemove(@TrampolineShortCutToText, @InterceptShortCutToText);

end.
