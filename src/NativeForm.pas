(**
 * $Id: NativeForm.pas 809 2014-05-07 06:08:42Z QXu $
 *
 * Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, either
 * express or implied. See the License for the specific language governing rights and limitations under the License.
 *)

unit NativeForm;

interface

implementation

uses
  Vcl.Forms,
  Cromis.Detours { http://www.cromis.net/blog/downloads/cromis-ipc/ };

{ RTL patch }

type
  TCustomFormOverride = class(TCustomForm)
  protected
    procedure InterceptDoCreate; virtual;
  end;

var
  TrampolineCustomFormDoCreate: procedure = nil;

procedure TCustomFormOverride.InterceptDoCreate;
begin
  TrampolineCustomFormDoCreate;
  Font.Handle := Screen.MenuFont.Handle;
end;

initialization

TrampolineCustomFormDoCreate := InterceptCreate(@TCustomFormOverride.DoCreate, @TCustomFormOverride.InterceptDoCreate);

finalization

InterceptRemove(@TrampolineCustomFormDoCreate, @TCustomFormOverride.InterceptDoCreate);

end.
