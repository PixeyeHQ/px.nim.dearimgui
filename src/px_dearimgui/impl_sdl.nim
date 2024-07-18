# Copyright 2021, NimGL contributors.

## ImGUI SDL2 Implementation
## ====
## Implementation based on the imgui examples implementations.
## Feel free to use and modify this implementation.
## This needs to be used along with a Renderer.
##
## Based on : https://github.com/ocornut/imgui/blob/master/backends/imgui_impl_sdl.cpp (2020-05-25)
## Based on : https://github.com/ryback08/imgui/blob/master/src/imgui/impl_sdl.nim
##

{.warning[HoleEnumConv]:off.}
import vendors/sdl
import dearimgui

var
  gWindow: pointer
  gMouseJustPressed: array[3, bool]
  gMouseCursors: array[ImGuiMouseCursor.high.int32 + 1, CursorPtr]
  gClipboardTextData: cstring


proc igSDL2GetClipboardText*(userData: pointer): cstring {.cdecl.} =
  if gClipboardTextData != nil:
    freeClipboardText(gClipboardTextData)
   # sdl2.free(gClipboardTextData)
  gClipboardTextData = sdl2.getClipboardText()
  #return cast[cstring](gClipboardTextData)



proc igSDL2SetClipboardText*(userData: pointer, text: ConstCString): void {.cdecl,varargs.} =
  discard sdl2.setClipboardText(text)

## You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
## - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
## - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
## Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
## If you have multiple SDL events and some of them are not meant to be used by dear imgui, you may need to filter events based on their windowID field.

proc charArrayToString*(a: openarray[char]): string =
  ##  Convert an array of char to a proper string.
  ##
  result = ""
  for c in a:
    if c == '\0':
      break
    add(result, $c)


proc igSDL2_ProcessEvent*(event: sdl2.Event) =
  let io = igGetIO()

  if event.kind == sdl2.MOUSEWHEEL:
    if event.wheel.x > 0:
      io.mouseWheelH += 1
    elif event.wheel.x < 0:
      io.mouseWheelH -= 1

    if event.wheel.y > 0:
      io.mouseWheel += 1
    elif event.wheel.y < 0:
      io.mouseWheel -= 1

  elif event.kind == sdl2.MOUSEBUTTONDOWN:
    if event.button.button == sdl2.BUTTON_LEFT:
      gMouseJustPressed[0] = true
    if event.button.button == sdl2.BUTTON_RIGHT:
      gMouseJustPressed[1] = true
    if event.button.button == sdl2.BUTTON_MIDDLE:
      gMouseJustPressed[2] = true

  elif event.kind == sdl2.TEXTINPUT:
    # XXX Why can't i cast this?
    let data = charArrayToString(event.text.text)
    io.addInputCharactersUTF8(data.cstring)

  elif event.kind == sdl2.KEYDOWN or event.kind == KEYUP:
    let key = event.key.keysym.scancode.int32

    io.keysDown[key] = event.kind == sdl2.KEYDOWN

    let modState = sdl2.getModState().ord()
    io.keyShift = (modState and KMOD_SHIFT.int) != 0
    io.keyCtrl = (modState and KMOD_CTRL.int) != 0
    io.keyAlt = (modState and KMOD_ALT.int) != 0

    # XXX does this work?  do we care abour win32?
    when defined(WIN32):
      io.keySuper = false
    else:
      io.keySuper = (modState and KMOD_GUI.int) != 0

  elif event.kind == sdl2.WINDOWEVENT:
     if event.window.event == sdl2.WINDOWEVENT_FOCUS_GAINED:
       io.addFocusEvent(true)
     elif event.window.event == sdl2.WINDOWEVENT_FOCUS_LOST:
       io.addFocusEvent(false)


proc igSDL2Init(window: WindowPtr): bool =
  # Set the window globally
  gWindow = window

  # Setup backend capabilities flags
  let io = igGetIO()

  # We can honor GetMouseCursor() values (optional)
  io.backendFlags = (io.backendFlags.int32 or
                     ImGuiBackendFlags.HasMouseCursors.int32).ImGuiBackendFlags

  # We can honor io.WantSetMousePos requests (optional, rarely used)
  io.backendFlags = (io.backendFlags.int32 or
                     ImGuiBackendFlags.HasSetMousePos.int32).ImGuiBackendFlags
  io.backendPlatformName = "imgui_impl_sdl"

  # Keyboard mapping. ImGui will use those indices to peek into the io.KeysDown[] array.
  proc setKeyMap(x: typeof(ImGuiKey.Tab), y: typeof(SDL_SCANCODE_TAB)) =
    io.keyMap[x.int32] = y.int32

  setKeyMap(ImGuiKey.Tab, SDL_SCANCODE_TAB)
  setKeyMap(ImGuiKey.LeftArrow, SDL_SCANCODE_LEFT)
  setKeyMap(ImGuiKey.LeftArrow, SDL_SCANCODE_LEFT)
  setKeyMap(ImGuiKey.RightArrow, SDL_SCANCODE_RIGHT)
  setKeyMap(ImGuiKey.UpArrow, SDL_SCANCODE_UP)
  setKeyMap(ImGuiKey.DownArrow, SDL_SCANCODE_DOWN)
  setKeyMap(ImGuiKey.PageUp, SDL_SCANCODE_PAGEUP)
  setKeyMap(ImGuiKey.PageDown, SDL_SCANCODE_PAGEDOWN)
  setKeyMap(ImGuiKey.Home, SDL_SCANCODE_HOME)
  setKeyMap(ImGuiKey.End, SDL_SCANCODE_END)
  setKeyMap(ImGuiKey.Insert, SDL_SCANCODE_INSERT)
  setKeyMap(ImGuiKey.Delete, SDL_SCANCODE_DELETE)
  setKeyMap(ImGuiKey.Backspace, SDL_SCANCODE_BACKSPACE)
  setKeyMap(ImGuiKey.Space, SDL_SCANCODE_SPACE)
  setKeyMap(ImGuiKey.Enter, SDL_SCANCODE_RETURN)
  setKeyMap(ImGuiKey.Escape, SDL_SCANCODE_ESCAPE)
  setKeyMap(ImGuiKey.KeyPadEnter, SDL_SCANCODE_KP_ENTER)
  setKeyMap(ImGuiKey.A, SDL_SCANCODE_A)
  setKeyMap(ImGuiKey.C, SDL_SCANCODE_C)
  setKeyMap(ImGuiKey.V, SDL_SCANCODE_V)
  setKeyMap(ImGuiKey.X, SDL_SCANCODE_X)
  setKeyMap(ImGuiKey.Y, SDL_SCANCODE_Y)
  setKeyMap(ImGuiKey.Z, SDL_SCANCODE_Z)

  # Load mouse cursors
  proc setCursor(x: typeof(ImGuiMouseCursor.Arrow), y: typeof(SDL_SYSTEM_CURSOR_ARROW)) =
    gMouseCursors[x.int32] = sdl2.createSystemCursor(y)

  setCursor(ImGuiMouseCursor.Arrow, SDL_SYSTEM_CURSOR_ARROW)
  setCursor(ImGuiMouseCursor.TextInput, SDL_SYSTEM_CURSOR_IBEAM)
  setCursor(ImGuiMouseCursor.ResizeAll, SDL_SYSTEM_CURSOR_SIZEALL)
  setCursor(ImGuiMouseCursor.ResizeNS, SDL_SYSTEM_CURSOR_SIZENS)
  setCursor(ImGuiMouseCursor.ResizeEW, SDL_SYSTEM_CURSOR_SIZEWE)
  setCursor(ImGuiMouseCursor.ResizeNESW, SDL_SYSTEM_CURSOR_SIZENESW)
  setCursor(ImGuiMouseCursor.ResizeNWSE, SDL_SYSTEM_CURSOR_SIZENWSE)
  setCursor(ImGuiMouseCursor.Hand, SDL_SYSTEM_CURSOR_HAND)
  setCursor(ImGuiMouseCursor.NotAllowed, SDL_SYSTEM_CURSOR_NO)

  # set clipboard functions
  when not defined(emscripten):
    io.setClipboardTextFn = igSDL2SetClipboardText
    io.getClipboardTextFn = igSDL2GetClipboardText
    io.clipboardUserData  = nil
   # _IMGUISetClipboardText
  # Check and store if we are on Wayland
  #g_MouseCanUseGlobalState = strncmp(SDL_GetCurrentVideoDriver(), "wayland", 7) != 0
  # HELP to translate
  # when defined(WIN32):
  #   echo "win32"
  return true


proc igSDL2InitForOpenGL*(window: WindowPtr, sdlGLContext: GlContextPtr ): bool=
  return igSDL2Init(window)


proc igSDL2Shutdown*() =
  gWindow = nil

  # Destroy last known clipboard data
  if gClipboardTextData != nil:
    freeClipboardText(gClipboardTextData)
   # sdl2.free(addr gClipboardTextData)

  gClipboardTextData = nil

  # Destroy SDL mouse cursors
  for i in 0 ..< ImGuiMouseCursor.high.int32 + 1:
    sdl2.freeCursor(gMouseCursors[i])
    gMouseCursors[i] = nil


proc igSDL2UpdateMousePosAndButtons() =
  let io = igGetIO()

  var mouse_x_local, mouse_y_local: cint
  let mouseState = sdl2.getMouseState(addr mouse_x_local, addr  mouse_y_local).uint8
  let mouseButtons = [(BUTTON_LMASK and mouseState) > 0,
                      (BUTTON_MMASK and mouseState) > 0,
                      (BUTTON_RMASK and mouseState) > 0]
  for i in 0 ..< 3:
    io.mouseDown[i] = gMouseJustPressed[i] or mouseButtons[i]
    gMouseJustPressed[i] = false

  let mousePosBackup = io.mousePos
  io.mousePos = ImVec2(x: -high(float32), y: -high(float32))

  let focused = true
  if focused:
    if io.wantSetMousePos:
      sdl2.warpMouseInWindow(nil, mousePosBackup.x.cint, mousePosBackup.y.cint)
    else:
      io.mousePos = ImVec2(x: mouse_x_local.float32, y: mouse_y_local.float32)


proc igSDL2UpdateMouseCursor() =
  let io = igGetIO()

  if (io.configFlags.int32 and ImGuiConfigFlags.NoMouseCursorChange.int32) == 1:
    return

  var igCursor: ImGuiMouseCursor = igGetMouseCursor()
  if igCursor == ImGuiMouseCursor.None or io.mouseDrawCursor:
    # Hide SDL2 mouse cursor if imgui is drawing it or if it wants no cursor
    discard sdl2.showCursor(false)

  else:
    # Show SDL2 mouse cursor
    var cursor = gMouseCursors[igCursor.int32]
    if cursor == nil:
      cursor = gMouseCursors[ImGuiMouseCursor.Arrow.int32]

    sdl2.setCursor(cursor)
    discard sdl2.showCursor(true)


# proc igSDL2UpdateGamepads() =
#   let io = igGetIO()
#   # TODO


proc igSDL2NewFrame*(window : WindowPtr, dt: float) =
  let io = igGetIO()
  assert io.fonts.isBuilt()

  # Setup display size (every frame to accommodate for window resizing)
  var
    w: cint
    h: cint
    displayW: int32
    displayH: int32

  getSize(window, w, h)
  glGetDrawableSize(window, displayW, displayH)
  if (getFlags(window) and SDL_WINDOW_MINIMIZED) != 0:
    (w, h) = (0.cint, 0.cint)

  io.displaySize = ImVec2(x: w.float32, y: h.float32)
  if w > 0 and h > 0:
    io.displayFramebufferScale = ImVec2(x: displayW / w, y: displayH / h)

  io.deltaTime = dt

  igSDL2UpdateMousePosAndButtons()
  igSDL2UpdateMouseCursor()

{.warning[HoleEnumConv]:on.}