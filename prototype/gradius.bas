option base 0
option explicit
'$INCLUDE: "SDL/SDL.bi"

type actor_t
    bmp as SDL_Surface ptr   'bitmap of actor.
    bmpfname as string       'filename of bitmap
    col as UInt32            'fallback rectangle color if bitmap is missing.
    rect as SDL_Rect         'Rectangle for fallback
    enabled as integer       'actor record is actually in use.
    die_offscreen as integer 'delete actor when fully offscreen.
    position_x as single     'screen position with sub-pixel precision.
    position_y as single     'screen position with sub-pixel precision.
    velocity_x as single     'if travelling automatically, this is velocity.
    velocity_y as single     'if travelling automatically, this is velocity.
    goodness as integer      'good guy, bad guy, neutral?
    gun_x as integer         'X offset on sprite of gun
    gun_y as integer         'Y offset of sprite of gun
    zorder as integer        'Z order on screen.
    die_at_ticks as Uint32   'Disable actor at this time, if > 0
    explode_ticks as Uint32  'ticks that actor spends exploding
end type

type bitmap_cache_t
    bmp as SDL_Surface ptr
    fname as string
end type

dim shared vidsurf as SDL_Surface ptr

redim shared actors(0) as actor_t
redim shared bitmaps(0) as bitmap_cache_t

'fractional seconds to travel from one side of screen to other.
const PLAYER_BULLET_SPEED = 0.75

'milliseconds between waves of baddies.
const SPAWN_BAD_GUY_THRESHOLD = 2500

const SCREEN_WIDTH = 800
const SCREEN_HEIGHT = 600

'The Functions...

'Report whether a point lands in a rectangular box.
' The bounding box must be normalized!
function in_rect(x as integer, y as integer, _
                 bx1 as integer, by1 as integer, _
                 bx2 as integer, by2 as integer) as integer
    if ((x < bx1) or (x > bx2)) then
        in_rect = 0

    elseif ((y < by1) or (y > by2)) then
        in_rect = 0

    else
        in_rect = 1
    end if
end function


'relatively cheap and inaccurate collision detection by entire rectangle.
function box_collision(px1 as integer, py1 as integer, _
                       px2 as integer, py2 as integer, _
                       bx1 as integer, by1 as integer, _
                       bx2 as integer, by2 as integer) as integer
    'if any corner of a rect is in the other, it's a collision...
    box_collision = ((in_rect(px1, py1, bx1, by1, bx2, by2)) or _
                     (in_rect(px2, py1, bx1, by1, bx2, by2)) or _
                     (in_rect(px1, py2, bx1, by1, bx2, by2)) or _
                     (in_rect(px2, py2, bx1, by1, bx2, by2)) or _
                     (in_rect(bx1, by1, px1, py1, px2, py2)) or _
                     (in_rect(bx2, by1, px1, py1, px2, py2)) or _
                     (in_rect(bx1, by2, px1, py1, px2, py2)) or _
                     (in_rect(bx2, by2, px1, py1, px2, py2)))
end function


function actor_collision(actor1 as actor_t ptr, actor2 as actor_t ptr)
    '!!! FIXME: Per-pixel collision would suck less.
    actor_collision = _
        (box_collision(cint(actor1->rect.x), cint(actor1->rect.y), _
                      cint(actor1->rect.x + actor1->rect.w), _
                      cint(actor1->rect.y + actor1->rect.h), _
                      cint(actor2->rect.x), cint(actor2->rect.y), _
                      cint(actor2->rect.x + actor2->rect.w), _
                      cint(actor2->rect.y + actor2->rect.h)))
end function


function load_bitmap(fname as string, colkeyr as integer, _
                    colkeyg as integer, colkeyb as integer) as SDL_Surface ptr

    if (fname = "") then
        load_bitmap = NULL
        exit function
    end if

    dim i as integer
    for i = 0 to ubound(bitmaps)-1
        if bitmaps(i).fname = fname then
            load_bitmap = bitmaps(i).bmp
            exit function
        end if
    next

    redim preserve bitmaps(i + 1) as bitmap_cache_t
    'print "now there are"; i + 1 ; " bitmap cache slots!"
    dim bmp as SDL_Surface ptr = SDL_LoadBMP(fname)
    if (bmp <> NULL) then
        dim colkey as UInt32
        colkey = SDL_MapRGB(bmp->format, colkeyr, colkeyg, colkeyb)
        SDL_SetColorKey(bmp, SDL_SRCCOLORKEY, colkey)
        dim converted as SDL_Surface ptr = SDL_DisplayFormat(bmp)
        if converted <> NULL then
            SDL_FreeSurface(bmp)
            bmp = converted
        end if
    end if

    if bmp = NULL then
        print "failed to load bitmap " + fname
    end if

    bitmaps(i).bmp = bmp
    bitmaps(i).fname = fname
    load_bitmap = bitmaps(i).bmp
end function

sub deinit
    dim i as integer
    for i = 0 to ubound(bitmaps)-1
        if bitmaps(i).bmp <> NULL then
            SDL_FreeSurface(bitmaps(i).bmp)
        end if
    next

    print "total bitmaps cache slots:"; ubound(bitmaps)
    print "total actor cache slots:"; ubound(actors)

    redim bitmaps(0) as bitmap_cache_t
    redim actors(0) as actor_t
    SDL_Quit
end sub

sub init_sdl
    if SDL_Init(SDL_INIT_VIDEO) = -1 then
        print "SDL_Init failed! (" ; SDL_GetError() ; ")"
        end
    end if

    SDL_WM_SetCaption("Gradius!", "gradius")
    SDL_ShowCursor(0)

    vidsurf = SDL_SetVideoMode(SCREEN_WIDTH, SCREEN_HEIGHT, 0, 0)
    if vidsurf = NULL then
        print "SDL_SetVideoMode failed! (" ; SDL_GetError() ; ")"
        deinit
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

sub calc_actor_velocity(actor as actor_t ptr, velx as single, vely as single)
    'divided by 3.0 would == 3 seconds from one side of screen to other.
    if (velx <> 0.0) then
        actor->velocity_x = vidsurf->w / velx
    end if
    if (vely <> 0.0) then
        actor->velocity_y = vidsurf->h / vely
    end if
end sub

function spawn_actor(fname as string, die_offscreen as integer, _
               rectr as integer, rectg as integer, rectb as integer, _
               colkeyr as integer, colkeyg as integer, colkeyb as integer, _
               x as integer, y as integer, _
               w as integer, h as integer) as actor_t ptr
    dim actor as actor_t ptr = NULL
    dim i as integer
    for i = 0 to ubound(actors)-1
        if (actors(i).enabled = 0) then
            'print "reused actor slot"; i
            actor = @actors(i)
            exit for
        end if
    next

    if actor = NULL then
        redim preserve actors(i + 1) as actor_t
        'print "now there are"; i + 1 ; " actor slots!"
        actor = @actors(i)
    end if

    actor->col = SDL_MapRGB(vidsurf->format, rectr, rectg, rectb)
    actor->enabled = 1
    actor->die_offscreen = die_offscreen
    actor->rect.x = x
    actor->rect.y = y
    actor->rect.w = w
    actor->rect.h = h
    actor->position_x = x
    actor->position_y = y
    actor->velocity_x = 0.0
    actor->velocity_y = 0.0
    actor->gun_x = -1
    actor->gun_y = -1
    actor->goodness = 0
    actor->zorder = 0
    actor->die_at_ticks = 0
    actor->explode_ticks = 0

    actor->bmpfname = fname
    actor->bmp = load_bitmap(fname, colkeyr, colkeyg, colkeyb)
    if actor->bmp <> NULL then
        actor->rect.w = w
        actor->rect.h = h
    end if

    spawn_actor = actor
end function

sub draw_actor(byref actor as actor_t)
    if actor.enabled <> 0 then
        if actor.bmp = NULL then
            SDL_FillRect(vidsurf, @actor.rect, actor.col)
        else
            SDL_BlitSurface(actor.bmp, NULL, vidsurf, @actor.rect)
        end if
    end if
end sub

sub draw_actors_by_zorder(z as integer)
    dim i as integer
    for i = 0 to ubound(actors)-1
        if (actors(i).zorder = z) then
            draw_actor(actors(i))
        end if
    next
end sub

sub draw_actors
    'This is wickedly inefficient, but what the hell, it's a prototype.
    dim z as integer
    for z = 0 to 1
        draw_actors_by_zorder(z)
    next
end sub


function actor_offscreen(byref actor as actor_t) as integer
    actor_offscreen = (box_collision(cint(actor.rect.x), cint(actor.rect.y), _
                                     cint(actor.rect.x + actor.rect.w), _
                                     cint(actor.rect.y + actor.rect.h), 0, 0, _
                                     cint(vidsurf->w), cint(vidsurf->h)) = 0)
end function

sub update_actor(byref actor as actor_t, fractionalTime as single)
    if actor.enabled <> 0 then
        actor.position_x += actor.velocity_x * fractionalTime
        actor.position_y += actor.velocity_y * fractionalTime
        actor.rect.x = actor.position_x  'keep these sane...
        actor.rect.y = actor.position_y  'keep these sane...
    end if

    if ( (actor.die_offscreen <> 0) and (actor_offscreen(actor) <> 0) ) then
        actor.enabled = 0
    end if

    if ( (actor.die_at_ticks > 0) and (SDL_GetTicks() >= actor.die_at_ticks) ) then
        actor.enabled = 0
    end if
end sub


sub explode(actor as actor_t ptr)
    dim fname as string = "boom2.bmp"
    if (actor->goodness > 0) then
        fname = "boom.bmp"
    end if
    actor->bmp = load_bitmap(fname, 255, 0, 255)
    actor->col = SDL_MapRGB(vidsurf->format, 255, 106, 0)
    actor->goodness = 0
    if (actor->explode_ticks = 0) then
        actor->enabled = 0
    else
        actor->die_at_ticks = SDL_GetTicks() + actor->explode_ticks
    end if
end sub

sub check_actor_collisions(idx as integer)
    dim actor as actor_t ptr = @actors(idx)
    if ((actor->enabled = 0) or (actor->goodness = 0)) then
        exit sub
    end if

    dim i as integer
    for i = 0 to ubound(actors)-1
        dim other as actor_t ptr = @actors(i)
        if ((i <> idx) and (other->enabled) and (other->goodness <> 0) and (other->goodness <> actor->goodness)) then
            if (actor_collision(actor, other)) then
                explode(actor)
                explode(other)
            end if
        end if
    next
end sub

function getshipidx() as integer
    getshipidx = 0  '!!! FIXME: hack
end function

function getship() as actor_t ptr
    getship = @actors(getshipidx())
end function


sub update_actors
    static last_ticks as Uint32 = 0
    dim ticks as Uint32 = SDL_GetTicks()
    if last_ticks = 0 then  'since setting fullscreen can take several seconds...
        last_ticks = ticks
    end if

    dim fractionalTime as single = (ticks - last_ticks) / 1000.0

    dim i as integer
    for i = 0 to ubound(actors)-1
        update_actor(actors(i), fractionalTime)
        check_actor_collisions(i)
    next

    'player died? Respawn. (!!! FIXME: this is a hack)
    dim ship as actor_t ptr = getship()
    if (ship->enabled = 0) then
        ship->enabled = 1
        ship->die_at_ticks = 0
        ship->bmp = load_bitmap("ship.bmp", 255, 0, 255)
        ship->col = SDL_MapRGB(vidsurf->format, 0, 0, 255)
        ship->goodness = 1
    end if

    last_ticks = ticks
end sub

sub draw_background
    'Blank the framebuffer.
    SDL_FillRect(vidsurf, NULL, SDL_MapRGB(vidsurf->format, 0, 0, 0))
    
    'Actors at Z-Order -1 are considered to be background elements and
    ' are drawn before anything else; this lets us have starfields, etc
    ' in the background behind even the terrain.
    draw_actors_by_zorder(-1)
end sub

sub draw_terrain
    '!!! FIXME
end sub

sub fire_bullet(shooteridx as integer, velx as single, vely as single)
    dim bullet as actor_t ptr = spawn_actor("bullet.bmp", 1, 255, 255, 255, 255, 0, 255, 0, 0, 13, 11)
    calc_actor_velocity(bullet, velx, vely)

    dim shooter as actor_t ptr = @actors(shooteridx)
    bullet->position_x = (shooter->rect.x + shooter->gun_x) - (bullet->rect.w / 2)
    bullet->position_y = (shooter->rect.y + shooter->gun_y) - (bullet->rect.h / 2)
    bullet->goodness = shooter->goodness
    bullet->zorder = shooter->zorder

    '!!! FIXME: lousy duplication...
    bullet->rect.x = shooter->gun_x
    bullet->rect.y = shooter->gun_y
end sub


sub update_events
    static last_ticks as Uint32 = 0
    dim ticks as Uint32 = SDL_GetTicks()
    if last_ticks = 0 then  'since setting fullscreen can take several seconds...
        last_ticks = ticks
    end if

    if (ticks - last_ticks > 100) then
        dim actor as actor_t ptr
        dim randval as single = rnd(1)
        dim x as integer = vidsurf->w - 10
        dim y as integer = cint(rnd(1) * vidsurf->h)
        if (randval < 0.10) then  'spawn bad guy
            actor = spawn_actor("baddy.bmp", 1, 255, 255, 0, 255, 0, 255, x, y, 32, 32)
            calc_actor_velocity(actor, -5.0, 0.0)
            actor->goodness = -1
            actor->explode_ticks = 500
        end if

        'Toss out another star.
        dim inten as integer = cint(rnd(1) * 224) + 32
        actor = spawn_actor("", 1, inten, inten, 0, 255, 0, 255, x, y, 1, 1)
        calc_actor_velocity(actor, rnd(1) * -30, 0.0)
        actor->goodness = 0
        actor->zorder = -1  'background actor.

        last_ticks = ticks
    end if
end sub

sub clampinput(byref v as Sint16, minval as integer, maxval as integer)
    if v < minval then
        v = minval
    elseif v > maxval then
        v = maxval
    end if
end sub

sub update_input(byref x as Sint16, byref y as Sint16)
    dim e as SDL_Event
    while SDL_PollEvent(@e) <> 0
        select case e.type
            case SDL_MOUSEMOTION
                if e.motion.xrel <> 0 then
                    x += e.motion.xrel
                    clampinput x, 0, vidsurf->w - getship()->rect.w
                end if
                if e.motion.yrel <> 0 then
                    y += e.motion.yrel
                    clampinput y, 0, vidsurf->h - getship()->rect.h
                end if

            case SDL_MOUSEBUTTONDOWN
                if (getship()->goodness <> 0) then
                    fire_bullet(getshipidx(), PLAYER_BULLET_SPEED, 0.0)
                end if

            case SDL_KEYDOWN
                if e.key.keysym.sym = SDLK_g then
                    if e.key.keysym.mod_ and KMOD_CTRL then
                        toggle_input_grab
                    end if
                elseif e.key.keysym.sym = SDLK_RETURN then
                    if e.key.keysym.mod_ and KMOD_ALT then
                        SDL_WM_ToggleFullscreen(vidsurf)
                    end if
                elseif e.key.keysym.sym = SDLK_ESCAPE then
                    deinit
                    end
                end if

            case SDL_QUIT_
                deinit
                end
        end select
    wend
end sub


sub mainline
    do
        update_input(getship()->rect.x, getship()->rect.y)  'may never return.
        getship()->position_x = getship()->rect.x  'keep these sane...
        getship()->position_y = getship()->rect.y
        update_events
        update_actors
        draw_background
        draw_terrain
        draw_actors
        SDL_Flip(vidsurf)
    loop 'indefinitely
end sub


sub init_game
    dim ship as actor_t ptr
    randomize timer
    ship = spawn_actor("ship.bmp", 0, 0, 0, 255, 255, 0, 255, 0, 0, 108, 43)
    ship->gun_x = 67
    ship->gun_y = 35
    ship->goodness = 1
    ship->zorder = 1
    ship->explode_ticks = 2000
end sub



'the real mainline...
init_sdl
init_game
mainline
deinit
end



'end of gradius.bas ...

