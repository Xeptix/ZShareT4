/*
======================================================================
    ZSHARE T4 v1.0  --  Weapon sharing for World at War Zombies
    Plutonium T4

    by Xep

======================================================================

    A port of ZShare (Plutonium T6) to World at War. Everything you can
    hand a teammate, from the button you buy everything else with:

        Weapons   Look at a teammate and press use. They see the gun in
                  your hands, look back at you and press use, and the
                  two weapons change hands, ammo and all.
        Points    Crouch first, then use: 1000 points go across.
        Box hits  Paid for a box weapon you do not want? Crouch and
                  press use at the box, and it is anyone's to take. The
                  same at the Pack-a-Punch on Der Riese.
        Paying    Crouch and press use at a perk machine, or at the box
                  or the Pack-a-Punch while nobody is using it, and the
                  next teammate to use that machine pays nothing.

        Install   %localappdata%\Plutonium\storage\t4\raw\scripts\sp

    Zombies runs on the singleplayer script tree, which is why the
    folder is sp. Everything runs on the host; nobody else needs this
    file.

----------------------------------------------------------------------
    HOW IT DIFFERS FROM THE T6 BUILD

    World at War gives a script less than any other engine ZShare runs
    on, and three differences follow from that:

      There is no trigger_radius_use, so a prompt on a player is a
      trigger_radius carrying the words, and the press is read by
      polling UseButtonPressed() while the reader is inside it and
      facing the player -- which is how the revive prompt works.

      A prompt cannot draw the use key. [{+activate}] is printed as
      written on this engine, so the prompts name the button instead:
      Hold USE to trade weapons.

      Every map carries its own copy of the zombiemode scripts and they
      differ, so every stock function is reached through getFunction and
      the map is checked before anything that only some maps have. Nacht
      der Untoten has no perks and no Pack-a-Punch; only Der Riese has
      the Pack-a-Punch.

    docs/porting-t4.md in the project has the detail.

----------------------------------------------------------------------
    VERIFICATION

    There is no compiler for this engine: Plutonium T4 loads raw source
    and compiles it at load. In its place, every call is checked against
    the stock T4 dump as a real call a zombies script can reach, and
    every field, notify, flag and sound it borrows is checked for
    existence there too. See audit.py and deep_check.py.

----------------------------------------------------------------------
    CREDITS

        Xep           author
        Treyarch      _zombiemode_weapons.gsc, _zombiemode_perks.gsc --
                      everything this stands on
        plutoniummod  t4-scripts, the stock script reference

----------------------------------------------------------------------
    LICENSE

        MIT -- see LICENSE. Keep this header on copies.

======================================================================
*/

/*
    These two are the only includes that resolve. The zombiemode scripts
    are not in the loaded tree when a raw script is compiled, so neither
    an #include of maps\_zombiemode_utility nor a qualified call into it
    can compile -- either stops World at War at boot. Everything from
    that tree is reached at runtime through getFunction(), the way
    Plutonium's own zm_spawn_fix.gsc does it; see FUNCTIONS.
*/
#include maps\_utility;
#include common_scripts\utility;


/* ==================================================================
    ENTRY POINT
   ================================================================== */

/*
    main() runs before the map threads its own loops, which is the one
    moment a stock function can be replaced and have every copy of it be
    ZShare's. Plutonium's own zm_spawn_fix.gsc replaces its functions
    from here for the same reason.
*/
main()
{
    if ( !zs_zombies() )
        return;

    level.zs_map = getdvar( "mapname" );

    zs_replace_stock();
    init();
}

init()
{
    if ( zs_true( level.zs_loaded ) )
        return;

    if ( !zs_zombies() )
        return;

    level.zs_loaded = 1;
    level.zs_map = getdvar( "mapname" );

    zs_load_config();
    zs_functions();

    level.zs_triggers = [];
    level.zs_player_sig = "";

    zs_chest_paid_clear();

    level thread zs_connect_watcher();
    level thread zs_trigger_updater();
    level thread zs_chests_watch();
    level thread zs_chest_teddy_watch();
    level thread zs_machines_watch();
    level thread zs_chat_listener();
    level thread zs_config_watcher();
    level thread zs_config_printer();
    level thread zs_build_watermark();
}

zs_zombies()
{
    return issubstr( getdvar( "mapname" ), "zombie" );
}

/*
    World at War has no is_true(): the helper every other port leans on
    is a Black Ops addition. Same behaviour by hand.
*/
zs_true( v )
{
    return isdefined( v ) && v;
}

zs_is_map( name )
{
    return isdefined( level.zs_map ) && level.zs_map == name;
}

// Nacht der Untoten has no perk machines and no Pack-a-Punch.
zs_has_perks()
{
    return !zs_is_map( "nazi_zombie_prototype" );
}

// Only Der Riese has the Pack-a-Punch.
zs_has_pap()
{
    return zs_is_map( "nazi_zombie_factory" );
}


/* ==================================================================
    FUNCTIONS

    Every stock zombiemode function this script calls, looked up once by
    path and name. The path is the same on every map; what it finds is
    that map's own copy, and they differ, so a lookup that finds nothing
    leaves the pointer undefined and each wrapper below falls back to
    the plainest version of the question it can answer itself.
   ================================================================== */

zs_functions()
{
    level.zs_f_valid          = getfunction( "maps/_zombiemode_utility", "is_player_valid" );
    level.zs_f_revive_trigger = getfunction( "maps/_zombiemode_utility", "in_revive_trigger" );
    level.zs_f_offhand        = getfunction( "maps/_zombiemode_utility", "is_offhand_weapon" );

    level.zs_f_upgraded       = getfunction( "maps/_zombiemode_weapons", "is_weapon_upgraded" );
    level.zs_f_has_family     = getfunction( "maps/_zombiemode_weapons", "has_weapon_or_upgrade" );

    level.zs_f_score_add      = getfunction( "maps/_zombiemode_score", "add_to_player_score" );
    level.zs_f_score_minus    = getfunction( "maps/_zombiemode_score", "minus_to_player_score" );
}

zs_player_valid( player )
{
    if ( !isdefined( player ) || !isplayer( player ) || !isalive( player ) )
        return 0;

    if ( isdefined( level.zs_f_valid ) )
        return [[ level.zs_f_valid ]]( player );

    return player.sessionstate == "playing";
}

/*
    Downed is a field on this engine: last stand gives the player a
    revive trigger and takes it away again on the revive.
*/
zs_downed( player )
{
    return isdefined( player.revivetrigger );
}

zs_in_revive_trigger( player )
{
    if ( !isdefined( level.zs_f_revive_trigger ) )
        return 0;

    return player [[ level.zs_f_revive_trigger ]]();
}

/*
    Drinking a perk, cracking knuckles or waving the bowie holds a
    weapon of its own for a moment; the machines mark the player while
    it plays.
*/
zs_drinking( player )
{
    return zs_true( player.is_drinking );
}

zs_is_offhand( weapon )
{
    if ( !isdefined( level.zs_f_offhand ) )
        return 0;

    return [[ level.zs_f_offhand ]]( weapon );
}

zs_is_upgraded( weapon )
{
    if ( isdefined( level.zs_f_upgraded ) )
        return [[ level.zs_f_upgraded ]]( weapon );

    return issubstr( weapon, "_upgraded" );
}

/*
    Points onto a player through the stock helper, which draws the +N
    popup every purchase draws and leaves the career total alone.
*/
zs_score_add( player, amount )
{
    if ( isdefined( level.zs_f_score_add ) )
    {
        player [[ level.zs_f_score_add ]]( amount );
        return;
    }

    player.score = player.score + amount;
}

zs_score_minus( player, amount )
{
    if ( isdefined( level.zs_f_score_minus ) )
    {
        player [[ level.zs_f_score_minus ]]( amount );
        return;
    }

    player.score = player.score - amount;
}


/* ==================================================================
    CONFIG

    Every value below is also a dvar of the same name, created with its
    default on load so the console can reach it. Re-read every five
    seconds and on every press, so a change applies without a restart.
   ================================================================== */

zs_load_config()
{
    if ( !isdefined( level.zs ) )
        level.zs = spawnstruct();

    // --- debug -----------------------------------------------------

    // Print what the script decides and why, to the host's screen.
    level.zs.debug            = zs_cfg_int( "zs_debug", 0 );

    // --- trading ---------------------------------------------------

    // Trade weapons with a teammate: use on them to offer, use back to accept.
    level.zs.trade            = zs_cfg_int( "zs_trade", 1 );

    // How long an offer stays open before it lapses on its own.
    level.zs.trade_offer_time = zs_cfg_float( "zs_trade_offer_time", 10 );

    // Whether a Pack-a-Punched weapon can be traded. Der Riese only,
    // since no other map has the machine.
    level.zs.trade_upgraded   = zs_cfg_int( "zs_trade_upgraded", 1 );

    /*
        How close you have to be for the prompt to appear, in units. An
        offer lapses on its own once the two of you are more than twice
        this apart. Read when a prompt is built, so a change reaches the
        prompts within a second.
    */
    level.zs.range            = zs_cfg_int( "zs_range", 64 );

    // --- points ----------------------------------------------------

    // Crouch, look at a teammate and press use to give them points.
    level.zs.points           = zs_cfg_int( "zs_points", 1 );
    level.zs.points_amount    = zs_cfg_int( "zs_points_amount", 1000 );

    // Seconds between gifts from one player, so a held button does not
    // empty a bank in a second.
    level.zs.points_cooldown  = zs_cfg_float( "zs_points_cooldown", 1 );

    // --- thanks ----------------------------------------------------

    /*
        Thank somebody who paid for you, gave up a box hit or handed you
        points: for a while the crouched prompt on them offers a small
        thank instead of the full gift, and !thank does the same from
        anywhere. !tip sends any amount to anybody, favour or not. The
        points come out of the thanker either way, so nothing is minted.
    */
    level.zs.thank            = zs_cfg_int( "zs_thank", 1 );
    level.zs.thank_amount     = zs_cfg_int( "zs_thank_amount", 100 );

    // How long a good turn stays thankable, in seconds.
    level.zs.thank_time       = zs_cfg_float( "zs_thank_time", 30 );

    // --- sharing ---------------------------------------------------

    // Share a box hit: crouch and press use at the box while the weapon
    // you paid for is up, and anybody can take it.
    level.zs.box_share        = zs_cfg_int( "zs_box_share", 1 );

    // The same at the Pack-a-Punch, for the upgraded weapon waiting there.
    level.zs.pap_share        = zs_cfg_int( "zs_pap_share", 1 );

    // --- paying ----------------------------------------------------

    /*
        Pay for a teammate. Crouch and press use at a perk machine, or at
        the box or the Pack-a-Punch while nobody is using it, and the next
        teammate to use that machine pays nothing. One payment waits at a
        machine at a time, and a crouched press from whoever paid takes it
        back.

        Off stops new payments only. One already waiting still works and
        can still be taken back.
    */
    level.zs.perk_pay         = zs_cfg_int( "zs_perk_pay", 1 );
    level.zs.box_pay          = zs_cfg_int( "zs_box_pay", 1 );
    level.zs.pap_pay          = zs_cfg_int( "zs_pap_pay", 1 );

    // --- perks -----------------------------------------------------

    /*
        How many perks one player can hold. World at War has no limit of
        its own -- every map with perks has exactly four machines -- so 0
        and -1 both mean four here, and any other number is a limit
        ZShare keeps itself.
    */
    level.zs.perk_limit       = zs_cfg_int( "zs_perk_limit", 0 );

    // --- presentation ----------------------------------------------

    // Tell players what the prompts do, once, shortly after they spawn.
    level.zs.show_hint        = zs_cfg_int( "zs_show_hint", 1 );

    // The one-line messages. Off leaves the prompts and the sounds.
    level.zs.messages         = zs_cfg_int( "zs_messages", 1 );

    // --- sounds ----------------------------------------------------

    /*
        Stock aliases, so the script stays one drop-in file. Set any to
        none for silence. World at War's names are its own: purchase and
        no_purchase are the buy and the refusal, cha_ching is the points
        sound behind a purchase.
    */
    level.zs.offer_sound      = zs_cfg_str( "zs_offer_sound", "powerup_grabbed" );
    level.zs.trade_sound      = zs_cfg_str( "zs_trade_sound", "weapon_show" );
    level.zs.share_sound      = zs_cfg_str( "zs_share_sound", "powerup_grabbed" );
    level.zs.points_sound     = zs_cfg_str( "zs_points_sound", "cha_ching" );
    level.zs.deny_sound       = zs_cfg_str( "zs_deny_sound", "no_purchase" );

    // Height of the prompt volume, in units. Not a setting.
    level.zs.height = 72;
}

/*
    set_dvar_if_unset() lives in the multiplayer utility, where a
    zombies script cannot reach it, so the same thing is done by hand:
    create the dvar with its default the first time, because the console
    can only assign to a dvar that already exists.

    An empty dvar reads as one that was never set and gets its default
    written straight back, so "" typed into the console would last until
    the next read. "none" is how a string setting is emptied instead.
*/
zs_cfg_str( dvar, def )
{
    if ( getdvar( dvar ) == "" )
        setdvar( dvar, def );

    value = zs_cfg_echo( dvar, getdvar( dvar ), def );

    if ( value == "none" )
        return "";

    return value;
}

zs_cfg_int( dvar, def )
{
    return int( zs_cfg_str( dvar, "" + def ) );
}

/*
    World at War has no float(). It appears nowhere in the stock scripts,
    and naming it costs the whole file: the compiler refuses to load a
    script that calls a function it does not have. A setting with a
    decimal point is read a digit at a time instead.

    Both settings that use it are times, so a negative reads as zero
    rather than being handled.
*/
zs_cfg_float( dvar, def )
{
    return zs_to_float( zs_cfg_str( dvar, "" + def ) );
}

zs_to_float( s )
{
    if ( !isdefined( s ) || s == "" )
        return 0;

    parts = strtok( s, "." );

    if ( parts.size == 0 )
        return 0;

    value = int( parts[0] );

    if ( parts.size < 2 )
        return value;

    digits = parts[1];
    scale = 1;

    for ( i = 0; i < digits.size; i++ )
        scale = scale * 10;

    return value + ( int( digits ) / scale );
}


/* ==================================================================
    PLAYERS
   ================================================================== */

zs_connect_watcher()
{
    level endon( "end_game" );

    // Anybody already in before this script initialised.
    players = get_players();

    for ( i = 0; i < players.size; i++ )
        players[i] thread zs_player_think();

    for (;;)
    {
        level waittill( "connected", player );
        player thread zs_player_think();
    }
}

zs_player_think()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( zs_true( self.zs_thinking ) )
        return;

    self.zs_thinking = 1;

    for (;;)
    {
        self waittill( "spawned_player" );

        /*
            A prompt is linked to the player it belongs to, and a respawn
            puts that player back into the world. Re-linking is cheap and
            saves finding out the hard way whether a link survives it.
        */
        zs_relink_prompts( self );

        if ( level.zs.show_hint && !zs_true( self.zs_hinted ) )
        {
            self.zs_hinted = 1;
            self thread zs_hint();
        }
    }
}

zs_hint()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    wait 12;

    if ( !isdefined( self ) )
        return;

    self iprintln( "^3[ZShare]^7 look at a teammate and press ^3USE^7 to trade weapons, or crouch first to give them points" );

    wait 4;

    if ( !isdefined( self ) )
        return;

    if ( zs_has_perks() )
        self iprintln( "^3[ZShare]^7 crouch and press ^3USE^7 at a perk machine or the box to pay for a teammate" );
    else
        self iprintln( "^3[ZShare]^7 crouch and press ^3USE^7 at the box to pay for a teammate, or to share your hit" );
}

/*
    Whether a player can take part at all: alive, on their feet, and not
    in the middle of something the game owns.
*/
zs_player_ok( player )
{
    if ( !zs_player_valid( player ) )
        return 0;

    if ( zs_downed( player ) )
        return 0;

    if ( zs_drinking( player ) )
        return 0;

    return 1;
}

/*
    Everything above, and not standing over a downed teammate: a crouch
    there is a revive, and the revive wins.
*/
zs_payer_ok( player )
{
    if ( !zs_player_ok( player ) )
        return 0;

    if ( zs_in_revive_trigger( player ) )
        return 0;

    return 1;
}

zs_pair_ok( a, b )
{
    if ( !isdefined( a ) || !isdefined( b ) || a == b )
        return 0;

    if ( !zs_player_ok( a ) || !zs_player_ok( b ) )
        return 0;

    return zs_game_ready();
}

zs_crouched( player )
{
    if ( !isdefined( player ) )
        return 0;

    stance = player getstance();

    return stance == "crouch" || stance == "prone";
}

/*
    Whether the viewer is looking at the target rather than merely
    standing near them. The engine's look-at test belongs to use
    triggers, which this game does not let a script spawn, so the test
    is done here the way the revive prompt does it.
*/
zs_facing( viewer, target )
{
    to = target.origin - viewer.origin;
    to = ( to[0], to[1], 0 );

    if ( lengthsquared( to ) < 1 )
        return 1;

    forward = anglestoforward( ( 0, viewer getplayerangles()[1], 0 ) );

    return vectordot( forward, vectornormalize( to ) ) >= 0.82;
}


/* ==================================================================
    PROMPTS ON PLAYERS

    One trigger per ordered pair of players, linked to the target and
    visible to one viewer, because the words depend on who is reading
    them: "accept the trade" is true for exactly one player, and "give
    points" only for a crouched one.

    There is no trigger_radius_use on this engine, so the trigger is a
    trigger_radius -- which draws its hint but never reports a press --
    and the press is read by polling UseButtonPressed() while the viewer
    is inside it and facing the target. That is how the revive prompt is
    built, and it is the only shape available.

    Every string on a prompt is one of a fixed handful. Hint strings are
    configstrings -- a finite pool that does not recycle -- so a weapon
    or player name never goes into one. Names go in the chat line.

    The use key cannot be drawn: [{+activate}] is printed as written on
    this engine, so the prompts name the button instead.
   ================================================================== */

zs_prompt_make( target, viewer )
{
    /*
        The revive trigger's recipe: a trigger_radius at the player,
        linked to them so it follows. Origin 36 up from the feet, where
        a player looks at another player.
    */
    t = spawn( "trigger_radius", target.origin + ( 0, 0, 36 ), 0, level.zs.range, level.zs.height );
    t setcursorhint( "HINT_NOICON" );
    t sethintstring( "" );

    // Once only: stock notes that setting it again is an error.
    t enablelinkto();
    t linkto( target );

    /*
        setvisibletoplayer() is exclusive on this engine -- the entity
        belongs to that player and nobody else -- which is exactly the
        one-viewer rule this needs. It starts hidden from them too, and
        is shown when it has words to show.
    */
    t setvisibletoplayer( viewer );
    t setinvisibletoplayer( viewer, true );

    t.zs_target = target;
    t.zs_viewer = viewer;
    t.zs_radius = level.zs.range;
    t.zs_hint = "";
    t.zs_shown = 0;

    t thread zs_prompt_think();

    level.zs_triggers[level.zs_triggers.size] = t;

    zs_debug( "prompt built: " + target.playername + " for " + viewer.playername );

    return t;
}

zs_prompt_find( target, viewer )
{
    for ( i = 0; i < level.zs_triggers.size; i++ )
    {
        t = level.zs_triggers[i];

        if ( !isdefined( t ) || !isdefined( t.zs_target ) || !isdefined( t.zs_viewer ) )
            continue;

        if ( t.zs_target == target && t.zs_viewer == viewer )
            return t;
    }

    return undefined;
}

/*
    Every ordered pair of players has a prompt. Run on a tick rather than
    on connect, so a late joiner, a rebuilt prompt and a changed range all
    heal the same way.
*/
zs_prompts_ensure()
{
    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        for ( j = 0; j < players.size; j++ )
        {
            if ( i == j )
                continue;

            if ( !isdefined( players[i] ) || !isdefined( players[j] ) )
                continue;

            if ( !isdefined( zs_prompt_find( players[i], players[j] ) ) )
                zs_prompt_make( players[i], players[j] );
        }
    }
}

/*
    The player list as one string. When it changes, somebody joined or
    left, and the pairs are rebuilt around it.
*/
zs_player_signature()
{
    sig = "";
    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[i] ) )
            sig = sig + players[i] getentitynumber() + ",";
    }

    return sig;
}

zs_relink_prompts( target )
{
    for ( i = 0; i < level.zs_triggers.size; i++ )
    {
        t = level.zs_triggers[i];

        if ( !isdefined( t ) || !isdefined( t.zs_target ) || t.zs_target != target )
            continue;

        t unlink();
        t.origin = target.origin + ( 0, 0, 36 );
        t linkto( target );
    }
}

zs_prompt_free( t )
{
    if ( !isdefined( t ) )
        return;

    t notify( "zs_kill" );
    t unlink();
    t delete();
}

/*
    The one loop behind every prompt on a player: who can see it, and
    what it says. Ten times a second, and the hint string is only
    written when it changes.
*/
zs_trigger_updater()
{
    level endon( "end_game" );

    tick = 0;

    for (;;)
    {
        wait 0.1;

        tick++;

        if ( tick % 10 == 0 )
        {
            zs_prompts_ensure();

            sig = zs_player_signature();

            if ( sig != level.zs_player_sig )
                level.zs_player_sig = sig;
        }

        keep = [];

        for ( i = 0; i < level.zs_triggers.size; i++ )
        {
            t = level.zs_triggers[i];

            if ( !isdefined( t ) )
                continue;

            if ( !isdefined( t.zs_target ) || !isdefined( t.zs_viewer ) || t.zs_radius != level.zs.range )
            {
                zs_prompt_free( t );
                continue;
            }

            t zs_prompt_update();
            keep[keep.size] = t;
        }

        level.zs_triggers = keep;
    }
}

zs_prompt_update()
{
    target = self.zs_target;
    viewer = self.zs_viewer;

    want = zs_prompt_text( target, viewer );

    /*
        A radius trigger shows its hint to anybody standing in it, so
        the facing test that a use trigger would do in the engine is
        done here: no words unless the viewer is looking at the target.
    */
    if ( want != "" && !zs_facing( viewer, target ) )
        want = "";

    if ( want == "" )
    {
        if ( self.zs_shown )
        {
            self setinvisibletoplayer( viewer, true );
            self.zs_shown = 0;
        }

        return;
    }

    if ( want != self.zs_hint )
    {
        self sethintstring( want );
        self.zs_hint = want;
    }

    if ( !self.zs_shown )
    {
        self setinvisibletoplayer( viewer, false );
        self.zs_shown = 1;
    }
}

/*
    What the viewer reads on the target, or "" for no prompt at all.
*/
zs_prompt_text( target, viewer )
{
    if ( !zs_pair_ok( target, viewer ) )
        return "";

    if ( level.zs.points && zs_crouched( viewer ) )
    {
        /*
            A thank takes the crouched press while one is owed, because
            crouch already means "give them something" and a thank is a
            smaller one with a reason.
        */
        if ( viewer zs_owes_thanks( target ) )
            return "Hold ^3USE^7 to thank them (" + level.zs.thank_amount + " points)";

        return "Hold ^3USE^7 to give " + level.zs.points_amount + " points";
    }

    if ( !level.zs.trade )
        return "";

    if ( zs_offer_is( target, viewer ) )
        return "Hold ^3USE^7 to accept the trade";

    if ( zs_offer_is( viewer, target ) )
        return "Hold ^3USE^7 to cancel the trade";

    return "Hold ^3USE^7 to trade weapons";
}

/*
    A radius trigger's own notify fires on touch, not on use, so the
    press is read here: the edge of the use button, while the prompt is
    up for this viewer and they are inside it. Twenty times a second,
    the rate the revive prompt polls at.
*/
zs_prompt_think()
{
    self endon( "zs_kill" );
    self endon( "death" );
    level endon( "end_game" );

    was = 0;

    for (;;)
    {
        wait 0.05;

        viewer = self.zs_viewer;
        target = self.zs_target;

        if ( !isdefined( viewer ) || !isdefined( target ) )
            continue;

        now = viewer usebuttonpressed();

        if ( now && !was && self.zs_shown && viewer istouching( self ) )
        {
            zs_load_config();
            viewer zs_use_on( target );

            // One press, one action.
            was = 1;
            wait 0.3;
            continue;
        }

        was = now;
    }
}

zs_use_on( target )
{
    if ( !zs_pair_ok( self, target ) )
        return;

    if ( level.zs.points && zs_crouched( self ) )
    {
        if ( self zs_owes_thanks( target ) )
            self zs_thank( target );
        else
            self zs_points_give( target );

        return;
    }

    if ( !level.zs.trade )
        return;

    // They offered first: this press accepts it.
    if ( zs_offer_is( target, self ) )
    {
        zs_trade_do( target, self );
        return;
    }

    // Pressing on the player you offered to withdraws the offer.
    if ( zs_offer_is( self, target ) )
    {
        self zs_offer_cancel( "withdrawn" );
        return;
    }

    self zs_offer_make( target );
}


/* ==================================================================
    TRADING

    What you offer is the weapon in your hands; what you get back is
    whatever they hold when they accept. No names anywhere: both of you
    can see the gun.
   ================================================================== */

zs_offer_is( from, to )
{
    if ( !isdefined( from ) || !isdefined( to ) )
        return 0;

    return isdefined( from.zs_offer_to ) && from.zs_offer_to == to;
}

zs_offer_make( to )
{
    weapon = self zs_held_weapon();
    why = self zs_untradeable( weapon );

    if ( why != "" )
    {
        self zs_deny( why );
        return;
    }

    if ( isdefined( self.zs_offer_to ) )
        self zs_offer_cancel( "replaced" );

    self.zs_offer_to = to;
    self.zs_offer_weapon = weapon;
    self.zs_offer_serial = zs_true( self.zs_offer_serial ) + 1;

    self zs_say( "Offered your weapon to ^3" + to.playername + "^7 -- they have "
                 + int( level.zs.trade_offer_time ) + " seconds to accept" );
    to zs_say( "^3" + self.playername + "^7 wants to trade weapons -- look at them and press ^3USE^7 to accept" );
    to zs_sound( level.zs.offer_sound );

    self thread zs_offer_watcher( self.zs_offer_serial );

    zs_debug( "offer: " + self.playername + " -> " + to.playername + " (" + weapon + ")" );
}

zs_offer_clear()
{
    self.zs_offer_to = undefined;
    self.zs_offer_weapon = undefined;
}

zs_offer_cancel( why )
{
    to = self.zs_offer_to;

    self zs_offer_clear();

    if ( why == "withdrawn" )
    {
        self zs_say( "Trade cancelled" );

        if ( isdefined( to ) )
            to zs_say( "^3" + self.playername + "^7 cancelled the trade" );
    }
    else if ( why == "expired" )
    {
        self zs_say( "Your trade offer lapsed" );

        if ( isdefined( to ) )
            to zs_say( "^3" + self.playername + "^7's trade offer lapsed" );
    }
    else if ( why == "switched" || why == "lost" )
    {
        self zs_say( "Trade cancelled -- you put the weapon away" );

        if ( isdefined( to ) )
            to zs_say( "^3" + self.playername + "^7 put the weapon away -- trade cancelled" );
    }
    else if ( why == "distance" )
    {
        self zs_say( "Trade cancelled -- too far apart" );

        if ( isdefined( to ) )
            to zs_say( "^3" + self.playername + "^7's trade offer lapsed -- too far apart" );
    }
    else if ( why == "replaced" )
    {
        if ( isdefined( to ) )
            to zs_say( "^3" + self.playername + "^7 withdrew the trade" );
    }

    zs_debug( "offer cancelled: " + why );
}

/*
    An offer lapses on its own: when it times out, when either of you
    goes down, when the offerer switches away from the weapon, or when
    the two of you walk apart.
*/
zs_offer_watcher( serial )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    started = gettime();

    for (;;)
    {
        wait 0.25;

        if ( !isdefined( self ) || !isdefined( self.zs_offer_to ) )
            return;

        if ( zs_true( self.zs_offer_serial ) != serial )
            return;

        to = self.zs_offer_to;

        if ( !isdefined( to ) )
            return;

        if ( gettime() - started > level.zs.trade_offer_time * 1000 )
        {
            self zs_offer_cancel( "expired" );
            return;
        }

        if ( !zs_player_ok( self ) || !zs_player_ok( to ) )
        {
            self zs_offer_cancel( "lost" );
            return;
        }

        if ( self zs_held_weapon() != self.zs_offer_weapon )
        {
            self zs_offer_cancel( "switched" );
            return;
        }

        if ( distance( self.origin, to.origin ) > level.zs.range * 2 )
        {
            self zs_offer_cancel( "distance" );
            return;
        }
    }
}

/*
    a offered, b accepted. Both weapons are read, taken and handed over
    together, so a failure on one side cannot leave the other empty
    handed.
*/
zs_trade_do( a, b )
{
    if ( !zs_pair_ok( a, b ) )
        return;

    a_weapon = a zs_held_weapon();
    b_weapon = b zs_held_weapon();

    if ( a_weapon != a.zs_offer_weapon )
    {
        a zs_offer_cancel( "switched" );
        return;
    }

    why = a zs_untradeable( a_weapon );

    if ( why != "" )
    {
        a zs_deny( why );
        a zs_offer_cancel( "lost" );
        return;
    }

    why = b zs_untradeable( b_weapon );

    if ( why != "" )
    {
        b zs_deny( why );
        return;
    }

    if ( zs_carries_same_family( b, a_weapon, b_weapon ) )
    {
        b zs_deny( "You already have that weapon" );
        return;
    }

    if ( zs_carries_same_family( a, b_weapon, a_weapon ) )
    {
        b zs_deny( "^3" + a.playername + "^7 already carries that weapon" );
        return;
    }

    a zs_offer_clear();

    a_record = a zs_take_with_alt( a_weapon );
    b_record = b zs_take_with_alt( b_weapon );

    b zs_weapon_give( a_record );
    a zs_weapon_give( b_record );

    a zs_say( "Traded weapons with ^3" + b.playername );
    b zs_say( "Traded weapons with ^3" + a.playername );

    a zs_sound( level.zs.trade_sound );
    b zs_sound( level.zs.trade_sound );

    zs_debug( "trade: " + a.playername + " " + a_weapon + " <-> " + b.playername + " " + b_weapon );
}

/*
    Take a weapon and report what left with it.

    World at War has no weapondata helper and no name for an underbarrel
    launcher: a Garand with one is two entries in GetWeaponsList(), the
    gun and m7_launcher_zombie, and taking the gun takes both. So the
    ammo of everything carried is read first, the gun is taken, and
    whatever else disappeared was hanging from it.
*/
zs_take_with_alt( weapon )
{
    r = [];
    r["name"] = weapon;
    r["clip"] = self getweaponammoclip( weapon );
    r["stock"] = self getweaponammostock( weapon );
    r["alt"] = "none";
    r["alt_clip"] = 0;
    r["alt_stock"] = 0;

    before = self getweaponslist();
    clips = [];
    stocks = [];

    for ( i = 0; i < before.size; i++ )
    {
        clips[before[i]] = self getweaponammoclip( before[i] );
        stocks[before[i]] = self getweaponammostock( before[i] );
    }

    self takeweapon( weapon );

    after = self getweaponslist();

    for ( i = 0; i < before.size; i++ )
    {
        w = before[i];

        if ( w == weapon || zs_list_has( after, w ) )
            continue;

        r["alt"] = w;
        r["alt_clip"] = clips[w];
        r["alt_stock"] = stocks[w];
        break;
    }

    return r;
}

zs_weapon_give( r )
{
    weapon = r["name"];

    self giveweapon( weapon, 0 );
    self setweaponammoclip( weapon, r["clip"] );
    self setweaponammostock( weapon, r["stock"] );

    /*
        The launcher arrives with the gun and with its own starting
        ammo, so its clip and stock are set after the give. The list is
        what says it arrived: HasWeapon() answers yes about names this
        map never loaded.
    */
    if ( r["alt"] != "none" && zs_list_has( self getweaponslist(), r["alt"] ) )
    {
        self setweaponammoclip( r["alt"], r["alt_clip"] );
        self setweaponammostock( r["alt"], r["alt_stock"] );
    }

    self switchtoweapon( weapon );
}

zs_list_has( list, name )
{
    for ( i = 0; i < list.size; i++ )
    {
        if ( list[i] == name )
            return 1;
    }

    return 0;
}

/*
    What you are holding, as the primary it belongs to. A player with a
    launcher under their gun is holding the gun; anything that is not a
    primary is not a weapon a trade can move.
*/
zs_held_weapon()
{
    weapon = self getcurrentweapon();

    if ( !isdefined( weapon ) || weapon == "none" || weapon == "" )
        return "none";

    return weapon;
}

zs_is_primary( player, weapon )
{
    if ( !isdefined( weapon ) || weapon == "none" )
        return 0;

    primaries = player getweaponslistprimaries();

    for ( i = 0; i < primaries.size; i++ )
    {
        if ( primaries[i] == weapon )
            return 1;
    }

    return 0;
}

/*
    Why a weapon cannot change hands, or "" when it can. Primaries only:
    grenades, the knife, mines and the drinks all have their own slots
    and their own rules.
*/
zs_untradeable( weapon )
{
    if ( !isdefined( weapon ) || weapon == "none" || weapon == "" )
        return "Hold the weapon you want to trade";

    // Revives, drinks and flourishes hold a weapon of their own for a
    // moment.
    if ( weapon == "syrette" || weapon == "zombie_knuckle_crack" || weapon == "zombie_bowie_flourish" || issubstr( weapon, "zombie_perk_bottle" ) )
        return "Hold the weapon you want to trade";

    // Grenades, the molotov, the monkey and the bouncing betty all
    // answer to this one; World at War has no powerup weapon to exclude.
    if ( zs_is_offhand( weapon ) )
        return "That isn't a weapon you can trade";

    if ( !zs_is_primary( self, weapon ) )
        return "Hold the weapon you want to trade";

    if ( !level.zs.trade_upgraded && zs_is_upgraded( weapon ) )
        return "Pack-a-Punched weapons can't be traded here";

    return "";
}

/*
    Whether the receiver already carries the incoming weapon, or its
    other half. The weapon they are giving away does not count, since it
    leaves in the same trade. Der Riese's box asks
    has_weapon_or_upgrade(); the other maps have no upgrades to ask
    about and the name alone answers it.
*/
zs_carries_same_family( receiver, incoming, outgoing )
{
    if ( incoming == outgoing )
        return 0;

    if ( isdefined( level.zs_f_has_family ) )
        return receiver [[ level.zs_f_has_family ]]( incoming );

    return zs_list_has( receiver getweaponslist(), incoming );
}


/* ==================================================================
    POINTS

    Through _zombiemode_score.gsc's own helpers, which draw the -N and
    +N popups every purchase draws.
   ================================================================== */

/* ==================================================================
    THANKS

    Somebody paid for your perk, gave up the box hit they paid for, or
    handed you points. ZShare already knows -- it says so at the time --
    so it remembers who, and for a while the crouched prompt on them
    offers a small thank instead of the full gift.

    The points come out of the thanker, so nothing is minted and there
    is nothing to farm: a thank is a gift with a reason attached, and
    what it buys is that the prompt tells you a favour is owed and takes
    one press to answer.

    One thank per favour, so the prompt stays meaningful. To give more,
    tip.
   ================================================================== */

/*
    Remember that `from` did `self` a good turn. The most recent one is
    the one that is owed; an older unthanked favour is simply replaced,
    because thanking is about the moment rather than a ledger.
*/
zs_favour_note( from )
{
    if ( !isdefined( from ) || !isdefined( self ) || from == self )
        return;

    if ( !isplayer( from ) || !isplayer( self ) )
        return;

    self.zs_favour_from = from;
    self.zs_favour_at = gettime();
}

zs_owes_thanks( to )
{
    if ( !level.zs.thank || !isdefined( to ) )
        return 0;

    if ( !isdefined( self.zs_favour_from ) || self.zs_favour_from != to )
        return 0;

    if ( level.zs.thank_amount <= 0 || self.score < level.zs.thank_amount )
        return 0;

    return gettime() - self.zs_favour_at < int( level.zs.thank_time * 1000 );
}

// Whoever is owed a thank right now, for the chat word.
zs_favour_who()
{
    if ( !isdefined( self.zs_favour_from ) )
        return undefined;

    if ( !self zs_owes_thanks( self.zs_favour_from ) )
        return undefined;

    return self.zs_favour_from;
}

zs_thank( to )
{
    if ( !zs_pair_ok( self, to ) )
        return;

    amount = level.zs.thank_amount;

    if ( self.score < amount )
    {
        self zs_deny( "You need " + amount + " points to thank them" );
        return;
    }

    self.zs_favour_from = undefined;

    zs_score_minus( self, amount );
    zs_score_add( to, amount );

    self zs_say( "Thanked ^3" + to.playername + "^7 -- " + amount + " points" );
    to zs_say( "^3" + self.playername + "^7 thanked you -- " + amount + " points" );

    self zs_sound( level.zs.points_sound );
    to zs_sound( level.zs.points_sound );

    zs_debug( "thanks: " + self.playername + " -> " + to.playername );
}

/*
    Any amount, to anybody, with no favour needed. The name is optional
    and the amount is always the last word, so a name with spaces in it
    still parses.
*/
zs_tip( rest )
{
    if ( !level.zs.thank )
        return;

    parts = strtok( rest, " " );

    if ( parts.size == 0 )
    {
        self zs_say( "Say ^3!tip 500^7, or ^3!tip <name> 500^7" );
        return;
    }

    amount = int( parts[parts.size - 1] );

    if ( amount <= 0 )
    {
        self zs_say( "Say ^3!tip 500^7, or ^3!tip <name> 500^7" );
        return;
    }

    if ( parts.size > 1 )
    {
        name = "";

        for ( i = 0; i < parts.size - 1; i++ )
            if ( name == "" )
                name = parts[i];
            else
                name = name + " " + parts[i];

        to = zs_player_named( name, self );

        if ( !isdefined( to ) )
            return;
    }
    else
    {
        to = self zs_favour_who();

        if ( !isdefined( to ) )
        {
            self zs_say( "Nobody owed a thank -- say ^3!tip <name> " + amount + "^7 instead" );
            return;
        }
    }

    if ( !zs_pair_ok( self, to ) )
        return;

    if ( self.score < amount )
    {
        self zs_deny( "You only have " + self.score + " points" );
        return;
    }

    zs_score_minus( self, amount );
    zs_score_add( to, amount );

    self zs_say( "Tipped ^3" + to.playername + "^7 " + amount + " points" );
    to zs_say( "^3" + self.playername + "^7 tipped you " + amount + " points" );

    self zs_sound( level.zs.points_sound );
    to zs_sound( level.zs.points_sound );

    zs_debug( "tip: " + self.playername + " -> " + to.playername + " " + amount );
}

/*
    The player a typed name means. Case and colour codes are ignored and
    a prefix is enough, but a name that matches nobody -- or more than
    one -- is refused rather than guessed at: somebody typing a name
    means that player, and sending their points to another is worse than
    doing nothing.
*/
zs_player_named( name, asker )
{
    want = tolower( name );
    found = undefined;
    several = 0;

    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        p = players[i];

        if ( !isdefined( p ) || p == asker )
            continue;

        theirs = tolower( zs_plain_name( p.playername ) );

        if ( theirs == want )
            return p;

        if ( getsubstr( theirs, 0, want.size ) != want )
            continue;

        if ( isdefined( found ) )
            several = 1;
        else
            found = p;
    }

    if ( several )
    {
        asker zs_say( "More than one player starts with ^3" + name + "^7" );
        return undefined;
    }

    if ( !isdefined( found ) )
        asker zs_say( "No player here called ^3" + name );

    return found;
}

// A name with the colour codes taken out, so typing it plainly matches.
zs_plain_name( name )
{
    out = "";

    for ( i = 0; i < name.size; i++ )
    {
        if ( name[i] == "^" && i + 1 < name.size )
        {
            i++;
            continue;
        }

        out = out + name[i];
    }

    return out;
}

zs_points_give( to )
{
    amount = level.zs.points_amount;

    if ( amount <= 0 )
        return;

    if ( !zs_pair_ok( self, to ) )
        return;

    if ( zs_true( self.zs_points_next ) && gettime() < self.zs_points_next )
        return;

    if ( self.score < amount )
    {
        self zs_deny( "You need " + amount + " points to give" );
        return;
    }

    self.zs_points_next = gettime() + int( level.zs.points_cooldown * 1000 );

    zs_score_minus( self, amount );
    zs_score_add( to, amount );

    to zs_favour_note( self );

    self zs_say( "Gave ^3" + to.playername + "^7 " + amount + " points" );
    to zs_say( "^3" + self.playername + "^7 gave you " + amount + " points" );

    self zs_sound( level.zs.points_sound );
    to zs_sound( level.zs.points_sound );

    zs_debug( "points: " + self.playername + " -> " + to.playername + " " + amount );
}


/* ==================================================================
    HOOKS

    World at War has no free state at the box, no anyone-can-grab state,
    and no validation hook at a machine: box_rerespun, auto_open and
    no_charge are Black Ops names and appear nowhere in this game. So
    ZShare works beside the stock loops rather than inside them -- its
    own prompt on its own trigger, the stock trigger hidden from the
    player reading ZShare's, and the press handed back to stock as a
    notify once the money has been sorted out. Stock takes a scripted
    press: its own timeout sends one every time a weapon is left in the
    box.

    The one exception is Der Riese's Pack-a-Punch take loop. That is a
    small function of its own, so it is replaced outright the way the T6
    and T5 builds replace theirs, which is what lets anybody take a
    shared weapon.
   ================================================================== */

zs_replace_stock()
{
    if ( zs_true( level.zs_replaced ) )
        return;

    level.zs_replaced = 1;

    if ( zs_has_perks() )
    {
        fn = getfunction( "maps/_zombiemode_perks", "check_player_has_perk" );

        if ( isdefined( fn ) )
        {
            replacefunc( fn, ::zs_perk_visibility, -1 );
            level.zs_perk_hooked = 1;
        }
    }

    if ( !zs_has_pap() )
        return;

    fn = getfunction( "maps/_zombiemode_perks", "wait_for_player_to_take" );

    if ( !isdefined( fn ) )
        return;

    replacefunc( fn, ::zs_pap_take, -1 );
    level.zs_pap_hooked = 1;
}

/*
    Shi No Numa runs the sumpf copy of the weapons script and every
    other map runs the plain one. getFunction() resolves a path rather
    than a map, so the right file has to be named.
*/
zs_weapons_path()
{
    if ( zs_is_map( "nazi_zombie_sumpf" ) )
        return "maps/_zombiemode_weapons_sumpf";

    return "maps/_zombiemode_weapons";
}

/*
    flag() faults on a flag nobody has created, and the box flags are
    created only on a map with more than one chest location.
*/
zs_flag( name )
{
    if ( !isdefined( level.flag ) || !isdefined( level.flag[name] ) )
        return 0;

    return level.flag[name];
}


/* ==================================================================
    MACHINE PROMPTS

    A machine's own trigger carries one hint for everybody, so ZShare
    cannot write its words on it: a payer and a taker standing at the
    same box need different prompts. Each machine gets a second trigger
    of ZShare's own, in the same place, shown to one player at a time --
    the same radius trigger and polled press the prompts on players use.
   ================================================================== */

zs_machine_trigger( kind )
{
    t = spawn( "trigger_radius", self.origin, 0, 72, 96 );
    t setcursorhint( "HINT_NOICON" );
    t sethintstring( "" );

    t.zs_machine = self;
    t.zs_kind = kind;
    t.zs_hint = "";
    t.zs_viewer = undefined;

    t thread zs_machine_trigger_think();

    return t;
}

/*
    Shown to one player, with one line of words, or to nobody. The
    exclusive setvisibletoplayer() is what makes a second prompt at the
    same machine possible at all.
*/
zs_trigger_show( t, player, want )
{
    if ( !isdefined( t ) )
        return;

    if ( !isdefined( player ) || want == "" )
    {
        if ( isdefined( t.zs_viewer ) )
        {
            t setinvisibletoplayer( t.zs_viewer, true );
            t.zs_viewer = undefined;
        }

        return;
    }

    if ( want != t.zs_hint )
    {
        t sethintstring( want );
        t.zs_hint = want;
    }

    if ( !isdefined( t.zs_viewer ) || t.zs_viewer != player )
    {
        if ( isdefined( t.zs_viewer ) )
            t setinvisibletoplayer( t.zs_viewer, true );

        t setvisibletoplayer( player );
        t setinvisibletoplayer( player, false );
        t.zs_viewer = player;
    }
}

zs_machine_trigger_think()
{
    self endon( "death" );
    level endon( "end_game" );

    was = 0;

    for (;;)
    {
        wait 0.05;

        viewer = self.zs_viewer;

        if ( !isdefined( viewer ) || !isdefined( self.zs_machine ) )
        {
            was = 0;
            continue;
        }

        now = viewer usebuttonpressed();

        if ( now && !was && viewer istouching( self ) )
        {
            zs_load_config();

            machine = self.zs_machine;

            switch ( self.zs_kind )
            {
                case "box":
                    machine zs_chest_press( viewer );
                    break;

                case "pap":
                    machine zs_pap_press( viewer );
                    break;

                case "perk":
                    machine zs_perk_press( viewer );
                    break;
            }

            was = 1;
            wait 0.3;
            continue;
        }

        was = now;
    }
}


/* ==================================================================
    THE BOX

    Stock keeps the buyer in a local: only Der Riese writes it to a
    field. So ZShare watches each chest itself -- who pressed it last
    before the weapon came up -- and hangs its own prompt beside it.

    Sharing serves the taker directly, because there is no state that
    means "anybody may take this": the weapon the box is offering is
    named on the spawn point, and the map's own give function hands it
    over. The stock loop is then closed the way its own timeout closes
    it, with user_grabbed_weapon first so the timeout thread ends, and
    the fake trigger after it.

    Paying is credit and forward: nothing makes the next spin free, so
    the taker is given the price and then charged for it by stock.
   ================================================================== */

zs_chests_watch()
{
    level endon( "end_game" );

    while ( !isdefined( level.chests ) )
        wait 0.5;

    for ( i = 0; i < level.chests.size; i++ )
    {
        if ( isdefined( level.chests[i] ) )
            level.chests[i] thread zs_chest_watch();
    }
}

/*
    One per chest location. Keeps track of who bought the weapon that is
    up, and drives ZShare's prompt beside the box.
*/
zs_chest_watch()
{
    self endon( "death" );
    level endon( "end_game" );

    self.zs_pay_trig = self zs_machine_trigger( "box" );
    self.zs_user = undefined;
    self.zs_shared = 0;

    self thread zs_chest_presses();

    was_up = 0;

    for (;;)
    {
        wait 0.1;

        up = zs_true( self.grab_weapon_hint );

        // The weapon has just come up: whoever pressed last bought it.
        if ( up && !was_up )
        {
            if ( isdefined( self.chest_user ) )
                self.zs_user = self.chest_user;
            else
                self.zs_user = self.zs_last_press;

            self.zs_shared = 0;
        }

        if ( !up && was_up )
        {
            self.zs_user = undefined;
            self.zs_shared = 0;
        }

        was_up = up;

        self zs_chest_prompt();
    }
}

/*
    Every press on the stock trigger, so the buyer is known on the three
    maps that keep no field for them. A notify reaches every thread
    waiting on it, so watching costs the stock loop nothing.
*/
zs_chest_presses()
{
    self endon( "death" );
    level endon( "end_game" );

    for (;;)
    {
        self waittill( "trigger", who );

        if ( isdefined( who ) && isplayer( who ) )
            self.zs_last_press = who;
    }
}

/*
    What ZShare's prompt at this chest says, and to whom. One viewer at
    a time: the first player in range it has something to say to.
*/
zs_chest_prompt()
{
    players = get_players();
    best = undefined;
    want = "";

    for ( i = 0; i < players.size; i++ )
    {
        p = players[i];

        if ( !isdefined( p ) || distance( p.origin, self.origin ) > 100 )
            continue;

        line = self zs_chest_line( p );

        if ( line == "" )
            continue;

        best = p;
        want = line;
        break;
    }

    zs_trigger_show( self.zs_pay_trig, best, want );
}

zs_chest_line( p )
{
    if ( !zs_payer_ok( p ) )
        return "";

    cost = zs_chest_cost( self );

    // A weapon is up: the player who paid for it can give it away.
    if ( zs_true( self.grab_weapon_hint ) )
    {
        if ( !level.zs.box_share || zs_true( self.zs_shared ) )
            return "";

        if ( !isdefined( self.zs_user ) || self.zs_user != p || !zs_crouched( p ) )
            return "";

        return "Hold ^3USE^7 to share this weapon";
    }

    if ( !zs_chest_is_live( self ) || zs_true( self.disabled ) )
        return "";

    // A payment is waiting at this box.
    if ( zs_true( level.zs_box_paid ) )
    {
        if ( zs_crouched( p ) )
        {
            if ( isdefined( level.zs_box_paid_by ) && level.zs_box_paid_by == p )
                return "Hold ^3USE^7 to take back your payment";

            return "";
        }

        return "Hold ^3USE^7 for a free spin";
    }

    if ( !zs_crouched( p ) || !level.zs.box_pay || !zs_pay_team_check() )
        return "";

    if ( cost <= 0 || p.score < cost )
        return "";

    return "Hold ^3USE^7 to buy a spin for a teammate [Cost: " + cost + "]";
}

/*
    What a spin costs at this chest. Stock copies it once per cycle from
    the trigger's own Radiant value; Nacht prints 950 on the hint and
    charges the same field as the rest.
*/
zs_chest_cost( chest )
{
    if ( isdefined( level.zombie_treasure_chest_cost ) )
        return level.zombie_treasure_chest_cost;

    if ( isdefined( chest.zombie_cost ) )
        return chest.zombie_cost;

    return 950;
}

/*
    Only the chest the box is currently at can be used, and not while it
    is flying to another spot.
*/
zs_chest_is_live( chest )
{
    if ( zs_flag( "moving_chest_now" ) )
        return 0;

    if ( !isdefined( level.chests ) || !isdefined( level.chest_index ) )
        return 0;

    if ( !isdefined( level.chests[level.chest_index] ) )
        return 0;

    return level.chests[level.chest_index] == chest;
}

// Nobody to pay for in solo.
zs_pay_team_check()
{
    return get_players().size > 1;
}

zs_chest_press( player )
{
    if ( !zs_payer_ok( player ) )
        return;

    line = self zs_chest_line( player );

    if ( line == "" )
        return;

    if ( issubstr( line, "share this weapon" ) )
    {
        self zs_chest_share( player );
        return;
    }

    if ( issubstr( line, "take back" ) )
    {
        self zs_chest_take_back( player );
        return;
    }

    if ( issubstr( line, "free spin" ) )
    {
        self zs_chest_free_use( player );
        return;
    }

    self zs_chest_pay( player );
}

/*
    Give the weapon that is up to whoever takes it next.

    There is no state on this engine that means "anybody may take this",
    so the taker is served here: the weapon is named on the spawn point,
    the map's own give function hands it over, and the stock loop is
    closed exactly as its timeout closes it -- user_grabbed_weapon first,
    so the timeout thread ends, then the fake trigger it waits on.
*/
zs_chest_share( player )
{
    self.zs_shared = 1;

    self setvisibletoall();

    zs_say_all( "^3" + player.playername + "^7 shared their box weapon -- anyone can take it" );
    zs_sound_others( player, level.zs.share_sound );

    self thread zs_chest_serve( player );

    zs_debug( "box shared by " + player.playername );
}

zs_chest_serve( owner )
{
    self endon( "death" );
    level endon( "end_game" );

    // The stock loop ends the moment the weapon is taken or times out.
    self thread zs_chest_serve_end();

    for (;;)
    {
        self waittill( "trigger", taker );

        if ( !zs_true( self.zs_shared ) || !zs_true( self.grab_weapon_hint ) )
            return;

        if ( !isdefined( taker ) || !isplayer( taker ) )
            continue;

        // The owner is still served by the stock loop.
        if ( isdefined( owner ) && taker == owner )
            return;

        if ( !zs_player_ok( taker ) )
            continue;

        weapon = self zs_chest_weapon();

        if ( weapon == "" )
            return;

        give = getfunction( zs_weapons_path(), "treasure_chest_give_weapon" );

        if ( !isdefined( give ) )
            return;

        self.zs_shared = 0;

        taker thread [[ give ]]( weapon );

        // Stock's own order: the first ends the timeout thread, the
        // second is the press its grab loop is waiting for.
        self notify( "user_grabbed_weapon" );
        self notify( "trigger", level );

        if ( isdefined( owner ) && owner != taker )
            owner zs_say( "^3" + taker.playername + "^7 took the weapon you shared" );
        zs_debug( "box share taken by " + taker.playername );
        return;
    }
}

zs_chest_serve_end()
{
    self endon( "death" );
    level endon( "end_game" );

    self waittill( "user_grabbed_weapon" );

    self.zs_shared = 0;
}

/*
    The weapon the box is offering, named on the spawn point the lid
    points at.
*/
zs_chest_weapon()
{
    if ( !isdefined( self.target ) )
        return "";

    lid = getent( self.target, "targetname" );

    if ( !isdefined( lid ) || !isdefined( lid.target ) )
        return "";

    spawn_org = getent( lid.target, "targetname" );

    if ( !isdefined( spawn_org ) || !isdefined( spawn_org.weapon_string ) )
        return "";

    return spawn_org.weapon_string;
}

zs_chest_pay( player )
{
    cost = zs_chest_cost( self );

    if ( cost <= 0 )
        return;

    if ( player.score < cost )
    {
        player zs_deny( "You need " + cost + " points" );
        return;
    }

    zs_score_minus( player, cost );

    level.zs_box_paid = 1;
    level.zs_box_paid_by = player;
    level.zs_box_paid_name = player.playername;
    level.zs_box_paid_amount = cost;

    player zs_say( "Paid for the next box spin -- the next teammate to use the box spins free" );
    zs_say_others( player, "^3" + player.playername + "^7 paid for the next box spin -- use the box to spin free" );
    player zs_sound( level.zs.points_sound );
    zs_sound_others( player, level.zs.share_sound );

    zs_debug( "box paid by " + player.playername + ": " + cost );
}

zs_chest_take_back( player )
{
    if ( !zs_true( level.zs_box_paid ) )
        return;

    amount = level.zs_box_paid_amount;

    zs_chest_paid_clear();
    zs_score_add( player, amount );

    player zs_say( "Took back your payment for the box" );
    zs_say_others( player, "^3" + player.playername + "^7 took back their payment for the box" );
    player zs_sound( level.zs.points_sound );

    zs_debug( "box payment taken back by " + player.playername );
}

/*
    Credit and forward. Nothing makes a spin free on this engine, so the
    taker is handed the price and the stock loop charges them for it:
    the press stock is waiting for is a notify, which its own timeout
    sends every time a weapon is left behind.
*/
zs_chest_free_use( player )
{
    if ( !zs_true( level.zs_box_paid ) )
        return;

    cost = zs_chest_cost( self );
    paid = level.zs_box_paid_amount;
    payer = level.zs_box_paid_by;
    name = level.zs_box_paid_name;

    zs_chest_paid_clear();

    /*
        The teddy bear refunds whoever spun, and on a spin somebody else
        paid for that is the wrong pocket. Remembered here, moved across
        by zs_chest_teddy_watch() if the bear turns up.
    */
    level.zs_box_paid_last_by = payer;
    level.zs_box_paid_last_amount = paid;

    zs_score_add( player, cost );

    self notify( "trigger", player );

    player zs_say( "^3" + name + "^7 paid for this spin" );
    player zs_favour_note( payer );

    if ( isdefined( payer ) && payer != player )
        payer zs_say( "^3" + player.playername + "^7 used the spin you paid for" );

    player zs_sound( level.zs.points_sound );

    zs_debug( "box payment used by " + player.playername + " (" + paid + ")" );

    self thread zs_chest_credit_watch( player, cost );
}

/*
    If the press did not start a spin -- the box moved, somebody else
    got there first, the player went down in the same moment -- the
    credit comes back off again.
*/
zs_chest_credit_watch( player, cost )
{
    self endon( "death" );
    level endon( "end_game" );

    wait 1;

    if ( !isdefined( player ) )
        return;

    if ( zs_true( self.disabled ) || zs_true( self.grab_weapon_hint ) )
        return;

    zs_score_minus( player, cost );
    player zs_say( "The box did not take it -- your points are back" );

    level.zs_box_paid = 1;
    level.zs_box_paid_by = player;
    level.zs_box_paid_name = player.playername;
    level.zs_box_paid_amount = cost;
}

zs_chest_paid_clear()
{
    level.zs_box_paid = 0;
    level.zs_box_paid_by = undefined;
    level.zs_box_paid_name = undefined;
    level.zs_box_paid_amount = 0;
}

/*
    The teddy bear pays the spinner 950 wherever the box moves, and on a
    spin somebody else paid for that is the wrong pocket. The refund is
    moved across once the move has been seen.
*/
zs_chest_teddy_watch()
{
    level endon( "end_game" );

    for (;;)
    {
        level waittill( "weapon_fly_away_start" );

        spinner = undefined;

        for ( i = 0; i < level.chests.size; i++ )
        {
            c = level.chests[i];

            if ( isdefined( c ) && isdefined( c.zs_user ) )
                spinner = c.zs_user;
        }

        payer = level.zs_box_paid_last_by;
        amount = level.zs_box_paid_last_amount;

        if ( !isdefined( spinner ) || !isdefined( payer ) || payer == spinner )
            continue;

        wait 1;

        if ( !isdefined( spinner ) || !isdefined( payer ) )
            continue;

        zs_score_minus( spinner, 950 );
        zs_score_add( payer, 950 );

        level.zs_box_paid_last_by = undefined;
        level.zs_box_paid_last_amount = 0;

        payer zs_say( "The teddy bear refunded the spin you paid for" );
        zs_debug( "teddy refund moved to " + payer.playername );
    }
}


/* ==================================================================
    PERK MACHINES  (Verruckt, Shi No Numa, Der Riese)

    A machine's own loop decides who may see it in check_player_has_perk,
    a small function of its own threaded once the power is on. ZShare
    replaces that one: the decision it makes is stock's, plus three of
    ZShare's own -- a crouched payer reads ZShare's prompt instead of the
    machine's, a player a drink is waiting for reads it too, and a player
    already holding zs_perk_limit perks is not offered another.

    There is no perk limit in this game to raise, and no free state to
    set, so paying is credit and forward. Der Riese charges before the
    drink; Verruckt and Shi No Numa charge after it and skip the charge
    entirely if the drinker goes down, so the credit is watched and taken
    back when no drink arrives.
   ================================================================== */

zs_machines_watch()
{
    level endon( "end_game" );

    if ( !zs_has_perks() )
        return;

    wait 1;

    machines = getentarray( "zombie_vending", "targetname" );

    for ( i = 0; i < machines.size; i++ )
    {
        if ( isdefined( machines[i] ) && isdefined( machines[i].script_noteworthy ) )
            machines[i] thread zs_perk_watch();
    }

    if ( !zs_has_pap() )
        return;

    paps = getentarray( "zombie_vending_upgrade", "targetname" );

    for ( i = 0; i < paps.size; i++ )
    {
        if ( isdefined( paps[i] ) )
            paps[i] thread zs_pap_watch();
    }
}

zs_perk_watch()
{
    self endon( "death" );
    level endon( "end_game" );

    self.zs_pay_trig = self zs_machine_trigger( "perk" );
    self.zs_paid = 0;

    for (;;)
    {
        wait 0.1;
        self zs_perk_prompt();
    }
}

zs_perk_prompt()
{
    players = get_players();
    best = undefined;
    want = "";

    for ( i = 0; i < players.size; i++ )
    {
        p = players[i];

        if ( !isdefined( p ) || distance( p.origin, self.origin ) > 100 )
            continue;

        line = self zs_perk_line( p );

        if ( line == "" )
            continue;

        best = p;
        want = line;
        break;
    }

    zs_trigger_show( self.zs_pay_trig, best, want );
}

zs_perk_line( p )
{
    if ( !zs_payer_ok( p ) )
        return "";

    perk = self.script_noteworthy;

    if ( !isdefined( perk ) || !zs_true( self.zs_powered ) )
        return "";

    cost = zs_perk_cost( perk );

    if ( zs_true( self.zs_paid ) )
    {
        if ( zs_crouched( p ) )
        {
            if ( isdefined( self.zs_paid_by ) && self.zs_paid_by == p )
                return "Hold ^3USE^7 to take back your payment";

            return "";
        }

        if ( p hasperk( perk ) )
            return "";

        if ( zs_perk_full( p ) )
            return "";

        return "Hold ^3USE^7 for a free perk";
    }

    if ( !zs_crouched( p ) )
        return "";

    if ( !level.zs.perk_pay || !zs_pay_team_check() )
        return "";

    if ( p.score < cost )
        return "";

    return "Hold ^3USE^7 to buy this perk for a teammate [Cost: " + cost + "]";
}

/*
    The price the machine's own loop sets for this perk, in the same
    switch it uses. The base is the zombie var every map sets to 2000.
*/
zs_perk_cost( perk )
{
    switch ( perk )
    {
        case "specialty_armorvest":
            return 2500;

        case "specialty_quickrevive":
            return 1500;

        case "specialty_fastreload":
            return 3000;

        case "specialty_rof":
            return 2000;
    }

    if ( isdefined( level.zombie_vars ) && isdefined( level.zombie_vars["zombie_perk_cost"] ) )
        return level.zombie_vars["zombie_perk_cost"];

    return 2000;
}

/*
    Whether a player is at the limit ZShare is keeping. World at War has
    none of its own -- every map with perks has exactly four machines --
    so 0 and -1 both mean four, and only a number below that is a limit
    anybody can reach.
*/
zs_perk_full( p )
{
    limit = level.zs.perk_limit;

    if ( limit <= 0 )
        return 0;

    return zs_perk_count( p ) >= limit;
}

zs_perk_count( p )
{
    n = 0;
    perks = [];
    perks[perks.size] = "specialty_armorvest";
    perks[perks.size] = "specialty_quickrevive";
    perks[perks.size] = "specialty_fastreload";
    perks[perks.size] = "specialty_rof";

    for ( i = 0; i < perks.size; i++ )
    {
        if ( p hasperk( perks[i] ) )
            n++;
    }

    return n;
}

zs_perk_press( player )
{
    if ( !zs_payer_ok( player ) )
        return;

    line = self zs_perk_line( player );

    if ( line == "" )
        return;

    if ( issubstr( line, "take back" ) )
    {
        self zs_perk_take_back( player );
        return;
    }

    if ( issubstr( line, "free perk" ) )
    {
        self zs_perk_free_use( player );
        return;
    }

    self zs_perk_pay( player );
}

zs_perk_pay( player )
{
    perk = self.script_noteworthy;
    cost = zs_perk_cost( perk );

    if ( player.score < cost )
    {
        player zs_deny( "You need " + cost + " points" );
        return;
    }

    zs_score_minus( player, cost );

    self.zs_paid = 1;
    self.zs_paid_by = player;
    self.zs_paid_name = player.playername;
    self.zs_paid_amount = cost;

    player zs_say( "Paid for " + zs_perk_name( perk ) + " -- the next teammate to use the machine drinks it free" );
    zs_say_others( player, "^3" + player.playername + "^7 paid for " + zs_perk_name( perk ) + " -- use the machine to drink it free" );
    player zs_sound( level.zs.points_sound );
    zs_sound_others( player, level.zs.share_sound );

    zs_debug( "perk paid by " + player.playername + ": " + perk + " " + cost );
}

zs_perk_take_back( player )
{
    if ( !zs_true( self.zs_paid ) )
        return;

    perk = self.script_noteworthy;
    amount = self.zs_paid_amount;

    self zs_perk_paid_clear();
    zs_score_add( player, amount );

    player zs_say( "Took back your payment for " + zs_perk_name( perk ) );
    zs_say_others( player, "^3" + player.playername + "^7 took back their payment for " + zs_perk_name( perk ) );
    player zs_sound( level.zs.points_sound );

    zs_debug( "perk payment taken back by " + player.playername );
}

/*
    Credit and forward, and then watch it. Der Riese charges before the
    drink, so the credit and the charge land together. Verruckt and Shi
    No Numa charge after it and skip the charge if the drinker goes down,
    which would leave the credit as a gift; no perk means no charge, so
    the credit comes back off.
*/
zs_perk_free_use( player )
{
    if ( !zs_true( self.zs_paid ) )
        return;

    perk = self.script_noteworthy;
    cost = self.zs_paid_amount;
    payer = self.zs_paid_by;
    name = self.zs_paid_name;

    self zs_perk_paid_clear();

    zs_score_add( player, cost );

    self notify( "trigger", player );

    player zs_say( "^3" + name + "^7 paid for this one" );
    player zs_favour_note( payer );

    if ( isdefined( payer ) && payer != player )
        payer zs_say( "^3" + player.playername + "^7 drank the " + zs_perk_name( perk ) + " you paid for" );

    player zs_sound( level.zs.points_sound );

    zs_debug( "perk payment used by " + player.playername + ": " + perk );

    self thread zs_perk_credit_watch( player, perk, cost );
}

zs_perk_credit_watch( player, perk, cost )
{
    self endon( "death" );
    level endon( "end_game" );

    // The drink takes a few seconds, and the machine charges for it at
    // one end or the other depending on the map.
    wait 9;

    if ( !isdefined( player ) )
        return;

    if ( player hasperk( perk ) )
        return;

    zs_score_minus( player, cost );

    if ( isdefined( player ) )
        player zs_say( "The machine did not pour -- the points went back" );

    self.zs_paid = 1;
    self.zs_paid_by = player;
    self.zs_paid_name = player.playername;
    self.zs_paid_amount = cost;

    zs_debug( "perk credit returned: " + perk );
}

zs_perk_paid_clear()
{
    self.zs_paid = 0;
    self.zs_paid_by = undefined;
    self.zs_paid_name = undefined;
    self.zs_paid_amount = 0;
}

/*
    The machine's own visibility loop, replaced.

    Stock shows the machine to every player within 128 units who does not
    already hold the perk and is not standing in a revive trigger, and
    hides it from everybody else, ten times a second. That is kept -- and
    the machine also steps aside for a crouched payer, for the player a
    drink is waiting for, and for anybody already at the limit ZShare is
    keeping.

    self is the machine trigger; perk is its own perk. Stock threads this
    once, after the power comes on.
*/
zs_perk_visibility( perk )
{
    self endon( "death" );
    level endon( "end_game" );

    self.zs_powered = 1;

    for (;;)
    {
        wait 0.1;

        players = get_players();

        for ( i = 0; i < players.size; i++ )
        {
            p = players[i];

            if ( !isdefined( p ) )
                continue;

            if ( distance( p.origin, self.origin ) > 128 )
            {
                self setinvisibletoplayer( p, true );
                continue;
            }

            if ( p hasperk( perk ) || zs_in_revive_trigger( p ) )
            {
                self setinvisibletoplayer( p, true );
                continue;
            }

            if ( zs_perk_full( p ) )
            {
                self setinvisibletoplayer( p, true );
                continue;
            }

            // ZShare's own prompt is up for this player: the machine's
            // words would sit on top of it.
            if ( self zs_perk_line( p ) != "" )
            {
                self setinvisibletoplayer( p, true );
                continue;
            }

            self setvisibletoplayer( p );
            self setinvisibletoplayer( p, false );
        }
    }
}

zs_perk_name( perk )
{
    switch ( perk )
    {
        case "specialty_armorvest":
            return "Juggernog";

        case "specialty_quickrevive":
            return "Quick Revive";

        case "specialty_fastreload":
            return "Speed Cola";

        case "specialty_rof":
            return "Double Tap";
    }

    return "perk";
}


/* ==================================================================
    THE PACK-A-PUNCH  (Der Riese)

    The take loop is a function of its own -- wait_for_player_to_take --
    so it is replaced with a copy of itself carrying the share branch,
    the same shape the T6 and T5 builds use. Everything else is the
    prompt beside the machine, and paying is credit and forward again:
    this machine charges up front, so the credit and the charge land in
    the same press.
   ================================================================== */

zs_pap_watch()
{
    self endon( "death" );
    level endon( "end_game" );

    self.zs_pay_trig = self zs_machine_trigger( "pap" );
    self.zs_paid = 0;
    self.zs_pap_window = 0;

    for (;;)
    {
        wait 0.1;
        self zs_pap_prompt();
    }
}

zs_pap_prompt()
{
    players = get_players();
    best = undefined;
    want = "";

    for ( i = 0; i < players.size; i++ )
    {
        p = players[i];

        if ( !isdefined( p ) || distance( p.origin, self.origin ) > 100 )
            continue;

        line = self zs_pap_line( p );

        if ( line == "" )
            continue;

        best = p;
        want = line;
        break;
    }

    zs_trigger_show( self.zs_pay_trig, best, want );
}

zs_pap_line( p )
{
    if ( !zs_payer_ok( p ) )
        return "";

    // A weapon is waiting in the machine for the player who bought it.
    if ( zs_true( self.zs_pap_window ) )
    {
        if ( !level.zs.pap_share || zs_true( self.zs_pap_shared ) )
            return "";

        if ( !isdefined( self.zs_pap_owner ) || self.zs_pap_owner != p || !zs_crouched( p ) )
            return "";

        return "Hold ^3USE^7 to share this weapon";
    }

    if ( zs_true( self.disabled ) )
        return "";

    if ( zs_true( self.zs_paid ) )
    {
        if ( zs_crouched( p ) )
        {
            if ( isdefined( self.zs_paid_by ) && self.zs_paid_by == p )
                return "Hold ^3USE^7 to take back your payment";

            return "";
        }

        return "Hold ^3USE^7 for a free Pack-a-Punch";
    }

    if ( !zs_crouched( p ) || !level.zs.pap_pay || !zs_pay_team_check() )
        return "";

    if ( p.score < 5000 )
        return "";

    return "Hold ^3USE^7 to buy a Pack-a-Punch for a teammate [Cost: 5000]";
}

zs_pap_press( player )
{
    if ( !zs_payer_ok( player ) )
        return;

    line = self zs_pap_line( player );

    if ( line == "" )
        return;

    if ( issubstr( line, "share this weapon" ) )
    {
        self zs_pap_share( player );
        return;
    }

    if ( issubstr( line, "take back" ) )
    {
        self zs_pap_take_back( player );
        return;
    }

    if ( issubstr( line, "free Pack-a-Punch" ) )
    {
        self zs_pap_free_use( player );
        return;
    }

    self zs_pap_pay( player );
}

zs_pap_share( player )
{
    self.zs_pap_shared = 1;
    self setvisibletoall();

    zs_say_all( "^3" + player.playername + "^7 shared their Pack-a-Punched weapon -- anyone can take it" );
    zs_sound_others( player, level.zs.share_sound );

    zs_debug( "pap shared by " + player.playername );
}

zs_pap_pay( player )
{
    /*
        World at War's Pack-a-Punch is a flat 5000 -- no bonfire sale on
        this engine, and all four maps charge the same -- so there is no
        price to read off the machine. Named once even so, because the
        charge, the refund and the words a player reads have to be the
        same number.
    */
    cost = 5000;

    if ( player.score < cost )
    {
        player zs_deny( "You need " + cost + " points" );
        return;
    }

    zs_score_minus( player, cost );

    self.zs_paid = 1;
    self.zs_paid_by = player;
    self.zs_paid_name = player.playername;
    self.zs_paid_amount = cost;

    player zs_say( "Paid for the next Pack-a-Punch -- the next teammate to use the machine packs free" );
    zs_say_others( player, "^3" + player.playername + "^7 paid for the next Pack-a-Punch -- use the machine to pack free" );
    player zs_sound( level.zs.points_sound );
    zs_sound_others( player, level.zs.share_sound );

    zs_debug( "pap paid by " + player.playername );
}

zs_pap_take_back( player )
{
    if ( !zs_true( self.zs_paid ) )
        return;

    amount = self.zs_paid_amount;

    self zs_pap_paid_clear();
    zs_score_add( player, amount );

    player zs_say( "Took back your payment for the Pack-a-Punch" );
    zs_say_others( player, "^3" + player.playername + "^7 took back their payment for the Pack-a-Punch" );
    player zs_sound( level.zs.points_sound );

    zs_debug( "pap payment taken back by " + player.playername );
}

zs_pap_free_use( player )
{
    if ( !zs_true( self.zs_paid ) )
        return;

    cost = self.zs_paid_amount;
    payer = self.zs_paid_by;
    name = self.zs_paid_name;

    self zs_pap_paid_clear();

    zs_score_add( player, cost );

    self notify( "trigger", player );

    player zs_say( "^3" + name + "^7 paid for this Pack-a-Punch" );
    player zs_favour_note( payer );

    if ( isdefined( payer ) && payer != player )
        payer zs_say( "^3" + player.playername + "^7 used the Pack-a-Punch you paid for" );

    player zs_sound( level.zs.points_sound );

    zs_debug( "pap payment used by " + player.playername );

    self thread zs_pap_credit_watch( player, cost );
}

/*
    The machine charges the moment it accepts the press, so a second is
    long enough to see whether it did. It refuses a weapon it has no
    upgrade for, a player mid-throw and a player switching weapons.
*/
zs_pap_credit_watch( player, cost )
{
    self endon( "death" );
    level endon( "end_game" );

    wait 1;

    if ( !isdefined( player ) )
        return;

    if ( zs_true( self.disabled ) || zs_true( self.zs_pap_window ) )
        return;

    zs_score_minus( player, cost );
    player zs_say( "The machine did not take it -- your points are back" );

    self.zs_paid = 1;
    self.zs_paid_by = player;
    self.zs_paid_name = player.playername;
    self.zs_paid_amount = cost;
}

zs_pap_paid_clear()
{
    self.zs_paid = 0;
    self.zs_paid_by = undefined;
    self.zs_paid_name = undefined;
    self.zs_paid_amount = 0;
}

/*
    wait_for_player_to_take() from Der Riese's _zombiemode_perks.gsc,
    with the share branch: once the weapon is shared, whoever presses is
    the taker. Stock's own body is kept otherwise -- the tick-tock, the
    two-primaries branch and the switch to the new gun.

    self is the machine trigger. Stock threads this for every upgrade.
*/
zs_pap_take( player, weapon, packa_timer )
{
    self endon( "pap_timeout" );

    self.zs_pap_owner = player;
    self.zs_pap_shared = 0;
    self.zs_pap_window = 1;

    self thread zs_pap_window_end();

    upgrade = weapon + "_upgraded";
    laststand = getfunction( "maps/_laststand", "player_is_in_laststand" );
    weapon_give = getfunction( zs_weapons_path(), "weapon_give" );

    while ( true )
    {
        packa_timer playloopsound( "ticktock_loop" );

        self waittill( "trigger", trigger_player );

        packa_timer stoploopsound( 0.05 );

        taker = player;

        // Once it is shared, whoever pressed takes it.
        if ( zs_true( self.zs_pap_shared ) && isdefined( trigger_player ) && isplayer( trigger_player ) )
            taker = trigger_player;

        if ( isdefined( trigger_player ) && trigger_player == taker && isdefined( taker ) )
        {
            down = 0;

            if ( isdefined( laststand ) )
                down = taker [[ laststand ]]();

            if ( !down )
            {
                self notify( "pap_taken" );

                primaries = taker getweaponslistprimaries();

                if ( isdefined( primaries ) && primaries.size >= 2 && isdefined( weapon_give ) )
                {
                    taker [[ weapon_give ]]( upgrade );
                }
                else
                {
                    taker giveweapon( upgrade );
                    taker givemaxammo( upgrade );
                }

                taker switchtoweapon( upgrade );

                if ( isdefined( player ) && taker != player )
                    player zs_say( "^3" + taker.playername + "^7 took the weapon you shared" );

                return;
            }
        }

        wait 0.05;
    }
}

zs_pap_window_end()
{
    self endon( "death" );
    level endon( "end_game" );

    self waittill_any( "pap_timeout", "pap_taken" );

    self.zs_pap_window = 0;
    self.zs_pap_shared = 0;
    self.zs_pap_owner = undefined;
}


/* ==================================================================
    INPUT -- CHAT

    One word, for when the machine is behind you. Nothing in the stock
    scripts listens for "say" and neither do Plutonium's own, but the
    notify arrives all the same: a line typed in a game reaches this
    with the message and the player who typed it.
   ================================================================== */

zs_chat_listener()
{
    level endon( "end_game" );

    for (;;)
    {
        level waittill( "say", message, player );

        if ( !isdefined( message ) || !isdefined( player ) )
            continue;

        if ( !isstring( message ) || !isplayer( player ) )
            continue;

        msg = tolower( message );

        if ( zs_word_is( msg, "!thank" ) || zs_word_is( msg, "!t" ) )
        {
            level thread zs_chat_thank( player );
            continue;
        }

        rest = zs_word_after( msg, "!tip" );

        if ( isdefined( rest ) )
        {
            level thread zs_chat_tip( player, rest );
            continue;
        }

        if ( zs_word_is( msg, "!share" ) )
            level thread zs_chat_share( player );
    }
}

/*
    Plutonium's say notify can hand the message over behind a stray
    control character, as it does on Black Ops II. Every comparison is
    made twice: on the message, and on the message less its first
    character.
*/
/*
    What follows a word, or undefined when the message is not that word.
    The same two comparisons zs_word_is makes, for the same reason.
*/
zs_word_after( msg, token )
{
    if ( getsubstr( msg, 0, token.size ) == token )
        return zs_trim( getsubstr( msg, token.size ) );

    if ( msg.size > 1 && getsubstr( msg, 1, token.size ) == token )
        return zs_trim( getsubstr( msg, 1 + token.size ) );

    return undefined;
}

zs_trim( s )
{
    while ( s.size > 0 && s[0] == " " )
        s = getsubstr( s, 1 );

    while ( s.size > 0 && s[s.size - 1] == " " )
        s = getsubstr( s, 0, s.size - 1 );

    return s;
}

zs_chat_thank( player )
{
    zs_load_config();

    if ( !isdefined( player ) || !level.zs.thank )
        return;

    to = player zs_favour_who();

    if ( !isdefined( to ) )
    {
        player zs_say( "Nobody has done you a good turn just now" );
        return;
    }

    player zs_thank( to );
}

zs_chat_tip( player, rest )
{
    zs_load_config();

    if ( isdefined( player ) )
        player zs_tip( rest );
}

zs_word_is( msg, token )
{
    if ( msg == token )
        return 1;

    if ( msg.size > 1 && getsubstr( msg, 1 ) == token )
        return 1;

    return 0;
}

zs_chat_share( player )
{
    zs_load_config();

    if ( !isdefined( player ) || !zs_player_ok( player ) )
        return;

    if ( level.zs.box_share && isdefined( level.chests ) )
    {
        for ( i = 0; i < level.chests.size; i++ )
        {
            c = level.chests[i];

            if ( !isdefined( c ) || !zs_true( c.grab_weapon_hint ) || zs_true( c.zs_shared ) )
                continue;

            if ( !isdefined( c.zs_user ) || c.zs_user != player )
                continue;

            c zs_chest_share( player );
            return;
        }
    }

    if ( level.zs.pap_share && zs_has_pap() )
    {
        paps = getentarray( "zombie_vending_upgrade", "targetname" );

        for ( i = 0; i < paps.size; i++ )
        {
            m = paps[i];

            if ( !isdefined( m ) || !zs_true( m.zs_pap_window ) || zs_true( m.zs_pap_shared ) )
                continue;

            if ( !isdefined( m.zs_pap_owner ) || m.zs_pap_owner != player )
                continue;

            m zs_pap_share( player );
            return;
        }
    }

    player zs_say( "Nothing of yours is waiting at the box or the Pack-a-Punch" );
}


/* ==================================================================
    PRESENTATION
   ================================================================== */

zs_say( txt )
{
    if ( !level.zs.messages || !isdefined( self ) )
        return;

    self iprintln( txt );
}

zs_say_all( txt )
{
    if ( !level.zs.messages )
        return;

    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[i] ) )
            players[i] iprintln( txt );
    }
}

zs_say_others( except, txt )
{
    if ( !level.zs.messages )
        return;

    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( !isdefined( players[i] ) )
            continue;

        if ( isdefined( except ) && players[i] == except )
            continue;

        players[i] iprintln( txt );
    }
}

zs_sound( alias )
{
    if ( !isdefined( alias ) || alias == "" || !isdefined( self ) )
        return;

    self playlocalsound( alias );
}

zs_sound_others( except, alias )
{
    if ( !isdefined( alias ) || alias == "" )
        return;

    players = get_players();

    for ( i = 0; i < players.size; i++ )
    {
        if ( !isdefined( players[i] ) )
            continue;

        if ( isdefined( except ) && players[i] == except )
            continue;

        players[i] playlocalsound( alias );
    }
}

zs_deny( why )
{
    self zs_say( why );
    self zs_sound( level.zs.deny_sound );
}

/*
    println() reaches no log on this game, so debug goes where a person
    can read it: the host's screen.
*/
zs_debug( txt )
{
    if ( !isdefined( level.zs ) || !zs_true( level.zs.debug ) )
        return;

    players = get_players();

    if ( players.size > 0 && isdefined( players[0] ) )
        players[0] iprintln( "^5[zs]^7 " + txt );
}

zs_game_ready()
{
    return isdefined( level.round_number );
}


/* ==================================================================
    BUILD STAMP

    A development build says so on screen: its version and the time it
    was built, top right, one line under ZPause's. Release builds carry
    an empty stamp and draw nothing.
   ================================================================== */

/*
    Written by tools/build.py. The line between the markers is generated --
    a version and a build time on a development build, an empty string on
    a release. Do not edit it by hand; the next build will overwrite it.
*/
zs_build()
{
    // ZS_BUILD_BEGIN
    return "";
    // ZS_BUILD_END
}

/*
    Hands the value straight back, so it can wrap a return. Silent unless
    zs_config_printer() has the echo on.
*/
zs_cfg_echo( dvar, value, def )
{
    if ( !zs_true( level.zs_cfg_echo ) )
        return value;

    if ( isdefined( level.zs_cfg_host ) && value != ( "" + def ) )
        level.zs_cfg_host iprintln( "^3" + dvar + "^7  " + value );

    return value;
}

zs_config_watcher()
{
    level endon( "end_game" );

    for (;;)
    {
        wait 5;
        zs_load_config();
    }
}

/*
    "set zs_config_print 1" in the console prints every setting that is
    not at its default to the host's screen, then puts the switch back.
*/
zs_config_printer()
{
    level endon( "end_game" );

    if ( getdvar( "zs_config_print" ) == "" )
        setdvar( "zs_config_print", "0" );

    for ( ;; )
    {
        wait 1;

        if ( getdvar( "zs_config_print" ) != "1" )
            continue;

        setdvar( "zs_config_print", "0" );

        level.zs_cfg_host = undefined;
        zs_cfg_players = get_players();

        if ( zs_cfg_players.size > 0 )
            level.zs_cfg_host = zs_cfg_players[0];

        if ( isdefined( level.zs_cfg_host ) )
            level.zs_cfg_host iprintln( "^3[ZShare]^7 settings changed from default:" );

        level.zs_cfg_echo = 1;
        zs_load_config();
        level.zs_cfg_echo = 0;

        if ( isdefined( level.zs_cfg_host ) )
            level.zs_cfg_host iprintln( "^3[ZShare]^7 end of settings" );

        level.zs_cfg_host = undefined;
    }
}

/*
    A plain newhudelem(), because createServerFontString() lives in a
    script a zombies script cannot include. The stock element tally is
    kept honest, as ZPause's T4 port keeps it.

    Scale 1.1: a font scale below 1 draws larger on this engine, not
    smaller.
*/
zs_build_watermark()
{
    level endon( "end_game" );

    stamp = zs_build();

    if ( stamp == "" )
        return;

    while ( !zs_game_ready() )
        wait 0.5;

    if ( isdefined( level.zs_build_hud ) )
        return;

    e = newhudelem();

    if ( isdefined( level.hudelem_count ) )
        level.hudelem_count++;

    e.horzalign = "right";
    e.vertalign = "top";
    e.alignx = "right";
    e.aligny = "top";
    e.x = 0;
    e.y = 26;
    e.fontscale = 1.1;
    e.color = ( 0.55, 0.85, 1 );
    e.sort = 1000;
    e.foreground = 1;
    e.alpha = 0.7;
    e settext( stamp );

    level.zs_build_hud = e;
}
