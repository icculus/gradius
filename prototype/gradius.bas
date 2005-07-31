option base 0
option explicit
'$INCLUDE: "SDL/SDL.bi"


dim shared vidsurf as SDL_Surface ptr

sub init
    if SDL_Init(SDL_INIT_VIDEO) = -1 then
        print "SDL_Init failed! (" ; SDL_GetError() ; ")"
        end
    end if

    SDL_WM_SetCaption("Gradius!", "gradius")
    SDL_ShowCursor(0)

    vidsurf = SDL_SetVideoMode(640, 480, 0, 0)
    if vidsurf = NULL then
        print "SDL_SetVideoMode failed! (" ; SDL_GetError() ; ")"
        SDL_Quit
        end
    end if
end sub

sub toggle_input_grab
    dim mode as SDL_GrabMode
    mode = SDL_WM_GrabInput(SDL_GRAB_QUERY)
    if mode = SDL_GRAB_ON then
        mode = SDL_GRAB_OFF
    else
        mode = SDL_GRAB_ON
    end if
    SDL_WM_GrabInput(mode)
end sub

sub update_input(byref shipx as integer, byref shipy as integer)
    dim e as SDL_Event
    while SDL_PollEvent(@e) <> 0
        select case e.type
            case SDL_KEYDOWN
                if e.key.keysym.sym = SDLK_g then
                    if e.key.keysym.mod_ and KMOD_CTRL then
                        toggle_input_grab
                    end if
                elseif e.key.keysym.sym = SDLK_ESCAPE then
                    SDL_Quit
                    end
                end if
            case SDL_MOUSEMOTION
                shipx = shipx + e.motion.xrel
                shipy = shipy + e.motion.yrel
            case SDL_QUIT_
                SDL_Quit
                end
        end select
    wend
end sub

sub blit(bmp as SDL_Surface ptr, x as integer, y as integer)
    dim rect as SDL_Rect
    rect.x = x
    rect.y = y
    rect.w = bmp->w
    rect.h = bmp->h
    SDL_BlitSurface(bmp, NULL, vidsurf, @rect)
end sub

sub draw_rect(x as integer, y as integer, w as integer, h as integer, _
              r as integer, g as integer, b as integer)

    dim rect as SDL_Rect
    dim rgbcolor as Uint32
    rect.x = x
    rect.y = y
    rect.w = w
    rect.h = h
    rgbcolor = SDL_MapRGB(vidsurf->format, r, g, b)
    SDL_FillRect(vidsurf, @rect, rgbcolor)
end sub

sub draw_background
    SDL_FillRect(vidsurf, NULL, 0)  '!!! FIXME
end sub

sub draw_terrain
end sub

sub draw_entities
end sub

sub draw_ship(shipx as integer, shipy as integer)
    static bmp as SDL_Surface ptr
    if bmp = NULL then
        bmp = SDL_LoadBMP("ship.bmp")
        if bmp = NULL then
            draw_rect(shipx, shipy, 40, 20, 255, 0, 0)
            exit sub
        else
            SDL_SetColorKey(bmp, SDL_SRCCOLORKEY, SDL_MapRGB(bmp->format, 255, 0, 255))
        end if
    end if

    blit(bmp, shipx, shipy)
end sub

sub mainline
    dim shipx as integer
    dim shipy as integer

    do
        update_input(shipx, shipy)  'may never return.
        draw_background
        draw_terrain
        draw_entities
        draw_ship(shipx, shipy)
        SDL_Flip(vidsurf)
    loop
end sub





'the real mainline...

init
mainline
SDL_Quit
end



'end of gradius.bas ...

