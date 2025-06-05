/*
*    AMXmod Script
*
*    Awp Map Extra by DanRaZor (c)
*
*    Turn awp map into a target based game. Shoot targets spawned.
*    And try not to kill other players ...
*
*    With help from AMXmod dev team.
*
*/

//----------------  Includes   ----------------//

#include <translator>
#include <amxmod>
#include <amxmisc>
#include <string>
#include <file>
#include <fun>
#include <vexd_utilities>
#include <cstrike>

// To use fm_strip_user_gun
#include <amxmodx_to_amx>

//---------------- Definitions ----------------//

// Cvar pointers
static cvarPointerAccel
static cvarPointerKeepH
static cvarPointerLight

#define MAP_NAME             "awp_map"

// Precache needed ////////////////
#define BARRIER_MDL          "models/barre.mdl"
#define BANNER_MDL           "models/banniere.mdl"
#define HOSTAGE_FORMAT       "models/otage%d.mdl"
#define BONUS_MDL            "models/bonus.mdl"
#define DEADBONUS_MDL        "models/bonusMort.mdl"
#define HOSTAGEDEAD_MDL      "models/palmtree2.mdl"

#define BONUS_SOUND          "misc/bonus.wav"
#define BONUS_T_SOUND        "misc/comeagain.wav"
///////////////////////////////////

#define BONUS_SPK_1          "spk misc/bonus"
#define BONUS_SPK_2          "spk misc/comeagain"

#define MISS_SPK_ZERO        "spk ambience/xtal_down1"
#define MISS_SPK_LOW_1       "spk weapons/gauss2"
#define MISS_SPK_LOW_2       "spk weapons/gauss2"
#define MISS_SPK_LOW_3       "spk weapons/xbow_hitbod2"
#define MISS_SPK_LOW_4       "spk weapons/xbow_hitbod2"

#define TOUCH_HOSTAGE1_SPK   "spk holo/tr_holo_nicejob"
#define TOUCH_HOSTAGE2_SPK   "spk barney/ba_close"

#define BONUS_KILLED_SPK     "spk barney/ba_gotone"
//#define BONUS_KILLED_SPK     "spk barney/yougotit"

#define HOSTAGE_KILLED_SPK   "spk items/medshot4"
//#define HOSTAGE_KILLED_SPK   "spk radio/enemydown"
//#define HOSTAGE_KILLED_SPK   "spk fvox/bell"
//#define HOSTAGE_KILLED_SPK   "spk buttons/bell1"

new extra_file[]             = "awp_map_score.cfg"  // Name of the best score saving file "hall of fame"
new translator_file[]        = "awp_map_extra"      // Translation file

#define FORMAT_HIGHSCORE     "%s : %s ( %d )"
#define FORMAT_NOHIGHSCORE   "No high score"

#define BEST_SCORE           "Best score"

#define NB_BONUS_MAX          30   // Max entities spawned for bonus
#define NB_HOSTAGE_MAX        20   // Max entities spawned for hostages

new lastEntity                = 0  // Last entity spawned

new tabEntBonus[NB_BONUS_MAX]     // To save and check bonus entities
new tabEntHostage[NB_HOSTAGE_MAX] // To save and check hostage entities

new scores[33]
new deads[33]
new totalScores[33]
new ranking[33]
new immunity[33]

new zone[33]              // Playing zone

#define IMMUNITY_TIME     10.0

new spriteWhite           // Entity for daredevil effect

new bonus                 = 0

new stop_enabled          = 0

new lastHighScore         = 0
new HighScore[100]        = ""

new Float:lastOrigin[3]   // Origin of last target

// Some generic tasks 
#define NOTKILL_TASK      998
#define NEWEXTRA_TASK     997
#define CONTROL_TASK      995
#define IMMUNITY_TASK_MAX 994

#define BONUS_VALUE       4      // Bonus IDs
#define BONUS_HOSTAGE     1
#define BONUS_HOSTAGE2    0

#define SCORE_PUNISHMENT  0      // Points removed when target missed
#define HP_PUNISHMENT     5      // Hp removed when target missed
#define BONUS_ZONE0       10     // Points for touched target
#define BONUS_BOT         1      // Points for bots

#define MIN_TIME          1.0    // Minimum time for target spawn
#define MAX_TIME          3.0    // Lifetime of normal target
#define MAX_TIME_BONUS    2.0    // Lifetime of bonus target

#define TIME_ACCELERATOR  get_cvarptr_float(cvarPointerAccel)
                                 // Higher means faster spawning/removing of target

#define HOSTAGEDEAD_KEEP  get_cvarptr_num(cvarPointerKeepH)
                                 
#define START_DELAY       5.0

#define EXTRA_SPEED       "2000"
#define EXTRA_FSPEED      2000.0

// For debug purposes
// Debug flags
new debug_extra           = 0
// Log file stored on "addons/amx/logs"
#define LOG_FILE          "debug_awp_map.log"
// MACRO 1
#define LOG_EXTRA         if (debug_extra == 1 ) log_to_file(LOG_FILE, 
// MACRO 2 - Always saved
//#define LOG_EXTRA_        log_to_file(LOG_FILE, 
#define LOG_EXTRA_        if (debug_extra == 1 ) log_to_file(LOG_FILE, 

//----------------   Methods   ----------------//

// Check map
public map_is_awp_map()
{
    new currentmap[30]
    get_mapname(currentmap, 29)
    if ( equali(currentmap, MAP_NAME) )
        return 1
    return 0
}

// Remove weapons at spawn points
public remove_weapons()
{
    LOG_EXTRA "remove_weapons - IN")
    remove_entities("armoury_entity")
    LOG_EXTRA "remove_weapons - OUT")
    return PLUGIN_CONTINUE
}

public move_ct_spawns()
{
    LOG_EXTRA "move_ct_spawns - IN")
    new Float:degreesvalue = 180.0
    new entId, Float:angles[3]
    do {
        entId = find_entity(entId, "info_player_start")
        if (entId != -1) {
            new Float:point[3];
            entity_get_vector(entId, EV_VEC_origin, point);
            //LOG_EXTRA "move_ct_spawns entity %d - %f,%f,%f", entId, point[0], point[1], point[2])
            entity_get_vector(entId, EV_VEC_angles, angles)
            angles[1] += degreesvalue
            entity_set_vector(entId, EV_VEC_angles, angles)
        }
    }
    while (entId != -1)
    LOG_EXTRA "move_ct_spawns - OUT")
    return PLUGIN_CONTINUE    
}

public move_t_spawns()
{
    LOG_EXTRA "move_t_spawns - IN")
    new Float:degreesvalue = 180.0
    new entId, Float:angles[3]
    do {
        entId = find_entity(entId, "info_player_deathmatch")
        if (entId != -1) {
            new Float:point[3];
            entity_get_vector(entId, EV_VEC_origin, point);
            point[0]=1796.0
            entity_set_vector(entId, EV_VEC_origin, point);
            //LOG_EXTRA "move_t_spawns  entity %d - %f,%f,%f", entId, point[0], point[1], point[2])
            entity_get_vector(entId, EV_VEC_angles, angles)
            angles[1] += degreesvalue
            entity_set_vector(entId, EV_VEC_angles, angles)
        }
    }
    while (entId != -1)
    LOG_EXTRA "move_t_spawns - OUT")
    return PLUGIN_CONTINUE    
}

// Add barriers and banners at spawn zone ...
public add_entities()
{
    LOG_EXTRA "add_entities - IN")
    new Float:YPos = -1450.0
    for ( new n = 0 ; n < 20 ; n ++ )
    {
        if ( n != 8 )
        {
            new entity = create_entity("info_target")
            if ( entity != 0 )
            {
                entity_set_string(entity, EV_SZ_classname, "barrier")
                entity_set_int(entity, EV_INT_movetype, MOVETYPE_NONE)
                entity_set_int(entity, EV_INT_solid, SOLID_SLIDEBOX)
                entity_set_model(entity, BARRIER_MDL)
                entity_set_float(entity, EV_FL_frame, 0.0)
                entity_set_int(entity, EV_INT_body, 3)
                entity_set_int(entity, EV_INT_sequence, 0)
                entity_set_int(entity, EV_INT_iuser2, 0)
                new Float:MinBox[3]
                new Float:MaxBox[3]
                MinBox[0] = -8.0
                MinBox[1] = -8.0
                MinBox[2] = -8.0
                MaxBox[0] = 8.0
                MaxBox[1] = 8.0
                MaxBox[2] = 8.0
                entity_set_vector(entity, EV_VEC_mins, MinBox)
                entity_set_vector(entity, EV_VEC_maxs, MaxBox)
                new Float:orig[3] = {1380.0,0.0,-515.0}
                orig[1] = YPos
                entity_set_origin(entity, orig)
            }
        }
        YPos = YPos + 125.0
    }
    new Float:position[3] = {1300.0,800.0,-475.0}
    YPos = 880.0
    position[1] = YPos
    for ( new t = 0 ; t < 12 ; t ++ )
    {
        new entity = CreateEntity("info_target")
        if ( entity != 0 ) 
        {
            entity_set_string(entity, EV_SZ_classname, "banniere")            
            entity_set_model(entity, BANNER_MDL)
            entity_set_int(entity, EV_INT_sequence, 1)
            entity_set_int(entity, EV_INT_solid, SOLID_SLIDEBOX)
            entity_set_origin(entity, position)
        }
        YPos = YPos - 217 - 10
        position[1] = YPos
    }
    LOG_EXTRA "add_entities - OUT")
    return PLUGIN_CONTINUE
}

// Check entities max for bonus killed ( remove first in )
public update_listBonus(ent)
{
    new done = 0
    for ( new e = 0 ; (e < NB_BONUS_MAX) && (done == 0) ; e++ )
    {
        if ( tabEntBonus[e] == 0 )
        {
            tabEntBonus[e] = ent
            done = 1
        }
    }
    if ( done == 0 )
    {
        /* No more room, remove first */
        LOG_EXTRA "update_listBonus - no more room")
        LOG_EXTRA "update_listBonus - remove_entity %d", tabEntBonus[0])
        remove_entity(tabEntBonus[0])
        LOG_EXTRA "update_listBonus - remove_entity OK")
        for (  new f = 1 ; f < NB_BONUS_MAX ; f++ )
            tabEntBonus[f-1] = tabEntBonus[f]  
        tabEntBonus[NB_BONUS_MAX-1] = ent
    }
}

// Check entities max for target killed ( remove first in )
public update_listHostage(ent)
{
    new done = 0
    for ( new e = 0 ; (e < NB_HOSTAGE_MAX) && (done == 0) ; e++ )
    {
        if ( tabEntHostage[e] == 0 )
        {
            tabEntHostage[e] = ent
            done = 1
        }
    }
    if ( done == 0 )
    {
        /* No more room, remove first */
        LOG_EXTRA "update_listHostage - no more room")
        LOG_EXTRA "update_listHostage - remove_entity %d", tabEntHostage[0])
        remove_entity(tabEntHostage[0])
        LOG_EXTRA "update_listHostage - remove_entity OK")
        for (  new f = 1 ; f < NB_HOSTAGE_MAX ; f++ )
            tabEntHostage[f-1] = tabEntHostage[f]  
        tabEntHostage[NB_HOSTAGE_MAX-1] = ent
    }
}

public update_rankings(lastKiller)
{
    //LOG_EXTRA "update_rankings - lastKiller = %d", lastKiller)
    new strRanking[256]
    format(strRanking, charsmax(strRanking), "IN  ranking - ")
    for ( new z = 1 ; z < 33 ; ++z )
    {
        if ( ranking[z] == 0 )
            break;
        new strTmp[10]
        format(strTmp, charsmax(strTmp), "%d,%d ", z, ranking[z])
        add(strRanking, charsmax(strRanking), strTmp)
    }
    LOG_EXTRA_ strRanking)
    
    for ( new z = 1 ; z < 33 ; ++z )
    {
        if ( ranking[z] == 0 )
        {
            ranking[z] = lastKiller
            break 
        } 
        else if ( ranking[z] != lastKiller )
        {
            if ( scores[lastKiller] > scores[ranking[z]]  )
            { 
                for ( new w = 32 ; w > z ; --w )
                { 
                    ranking[w] = ranking[w-1] 
                } 
                ranking[z] = lastKiller 
                new dec = 0
                for ( new x = z+1 ; x < 33 ; ++x )
                { 
                    if ( ranking[x] == lastKiller )
                    { 
                        ++dec    
                        ranking[33-dec] = 0
                    } 
                    if ( x+dec < 33 ) 
                        ranking[x] = ranking[x+dec]                
                } 
                break
            }
            else if ( scores[ranking[z]] == scores[lastKiller] )
            {
                if ( deads[lastKiller] < deads[ranking[z]] )
                {
                    for ( new w = 32 ; w > z ; --w )
                    { 
                        ranking[w] = ranking[w-1]
                    } 
                    ranking[z]   = lastKiller 
                    new dec = 0 
                    for ( new x = z+1 ; x < 33 ; ++x )
                    { 
                        if ( ranking[x] == lastKiller )
                        { 
                            ++dec    
                            ranking[33-dec] = 0 
                        } 
                        if ( x+dec < 33 ) 
                            ranking[x] = ranking[x+dec]
                    } 
                    break
                }
            }
        } 
        else if ( ranking[z] == lastKiller )
        { 
            break 
        } 
    } 
    
    format(strRanking, charsmax(strRanking), "OUT ranking - ")
    for ( new z = 1 ; z < 33 ; ++z )
    {
        if ( ranking[z] == 0 )
            break;
        new strTmp[10]
        format(strTmp, charsmax(strTmp), "%d,%d ", z, ranking[z])
        add(strRanking, charsmax(strRanking), strTmp)
    }
    LOG_EXTRA_ strRanking)
    
    return PLUGIN_CONTINUE 
} 

// Make sure player stays in the zone
public check_player_zone(id)
{
    //LOG_EXTRA "check_player_zone - id = %d", id)
    new orign[3]
    get_user_origin(id, orign)
    if (  zone[id] == 1 )
    {
        // Normal zone ...
        if ( orign[0] < 1434 )
        {
            orign[0] = 1440
            set_user_origin(id, orign)
        }
    }
    else
    {
        // Target zone ...
        if ( orign[0] > -160 )
        {
            orign[0] = -166
            set_user_origin(id, orign)
        }
    }
}

public start_player_control()
{
    //LOG_EXTRA "start_player_control")
    for ( new ii = 1 ; ii < 33 ; ii++ )
    {
        if ( is_user_connected(ii) )
            if ( is_user_alive(ii) )
                check_player_zone(ii)
    }    
    set_task(0.1, "start_player_control", CONTROL_TASK)
}

// For immunity at start/connection
public remove_immunity(id)
{
    LOG_EXTRA "remove_immunity - id %d", IMMUNITY_TASK_MAX-id)
    immunity[IMMUNITY_TASK_MAX-id] = 0
    return PLUGIN_CONTINUE
}

public client_putinserver(id)
{
    if ( map_is_awp_map() ) 
    {
        new playerName[32]
        get_user_name(id, playerName, charsmax(playerName))
        LOG_EXTRA_ "client_putinserver %d - %s", id, playerName)
        immunity[id] = 1
        if ( ! is_user_bot(id) )
            zone[id] = 1
        else
            zone[id] = 0
        LOG_EXTRA "client_putinserver - remove_immunity in %f", IMMUNITY_TIME)
        set_task(IMMUNITY_TIME, "remove_immunity", IMMUNITY_TASK_MAX-id)
        if ( ! is_user_bot(id) )
            show_beginning(id)
        scores[id] = 0
        totalScores[id] = 0
        deads[id]  = 0
        set_user_money(id, 16000)
    }
    return PLUGIN_CONTINUE
}

public client_disconnect(id)
{
    if ( map_is_awp_map() ) 
    {
        new playerName[32]
        get_user_name(id, playerName, charsmax(playerName))
        LOG_EXTRA_ "client_disconnect %d - %s", id, playerName)
        scores[id] = 0
        totalScores[id] = 0
        deads[id]  = 0
        for ( new z = 1 ; z < 33 ; ++z ) { 
            if ( ranking[z] == id ) { 
                for ( new t = z ; t < 32 ; ++t ) 
                    ranking[t] = ranking[t+1] 
                ranking[32] = 0 
                return PLUGIN_CONTINUE 
            } 
        }
        if ( task_exists(id) )
            remove_task(id)
    }
    return PLUGIN_CONTINUE
}

// Spawn random target
public create_hostage(Float:origin[3], Float:angles[3])
{
    LOG_EXTRA "create_hostage - IN")
    if ( lastEntity != 0 )
    {
        LOG_EXTRA "create_hostage - remove_entity %d", lastEntity)
        remove_entity(lastEntity)
        LOG_EXTRA "create_hostage - remove_entity OK")
        lastEntity = 0
    }
    LOG_EXTRA "create_hostage - create_entity ...")
    new hostage = create_entity("hostage_entity")
    LOG_EXTRA "create_hostage - create_entity : %d", hostage)
    if ( hostage != 0 )
    {
        entity_set_string(hostage, EV_SZ_classname, "otage_cible")    
        new ran = random_num(1,3)
        new model[40]
        if ( ran < 3 )
        {
            if ( ran == 2 )
                bonus = BONUS_HOSTAGE2
            else
                bonus = BONUS_HOSTAGE
            format(model, 39 , HOSTAGE_FORMAT, ran)
        }
        else
        {
            bonus = BONUS_VALUE
            format(model, 39 , BONUS_MDL, ran)
            for ( new f = 1 ; f < 33 ; f++ )
                if ( is_user_connected(f) )
                    if ( ! is_user_bot( f ) )
                        if ( is_user_alive(f) )
                        {
                            LOG_EXTRA "create_hostage - %s", BONUS_SPK_1)
                            client_cmd(f, BONUS_SPK_1)
                        }
        }
        entity_set_model(hostage, model)
        entity_set_origin(hostage, origin)
        entity_set_vector(hostage, EV_VEC_angles, angles);

        if ( bonus != BONUS_VALUE )
        {
            // Make model run ... not working yet ...
            /*
            static Float:velocity[3]
            entity_get_vector(hostage, EV_VEC_velocity, velocity)
            velocity[0] += random_float(-60.0,60.0)
            velocity[1] += random_float(-60.0,60.0)
            LOG_EXTRA "create_hostage - entity_set_vector [%f;%f,%f]", velocity[0], velocity[1], velocity[2])
            entity_set_vector(hostage, EV_VEC_velocity, velocity)
            LOG_EXTRA "create_hostage - entity_set_int EV_INT_movetype MOVETYPE_WALK")
            entity_set_int(hostage, EV_INT_movetype, MOVETYPE_WALK)
            entity_set_float(hostage, EV_FL_framerate, 1.0)
            entity_set_float(hostage, EV_FL_frame, 0.0)
            */
        }
        
        LOG_EXTRA "create_hostage - DispatchSpawn %d", hostage)
        DispatchSpawn(hostage)
    }
    lastEntity = hostage
    LOG_EXTRA "create_hostage - OUT - lastEntity = %d", lastEntity)
    return PLUGIN_CONTINUE
}

public get_random_origin(Float:origin[])
{
    // Triangle Points
    new Float:X_A   = -1030.0
    new Float:Y_A   =   338.0
    new Float:X_B   =    70.0
    new Float:Y_B   =  -377.0
    new Float:X_C   = -1030.0
    new Float:Y_C   =  -916.0
    new Float:Z_MIN =  -475.0
    new Float:Z_MAX =  -411.0
    // Random Point Position = A + R*AB + S*AC
    new Float:randR = random_float(0.0,1.0)
    new Float:randS = random_float(0.0,1.0)
    if ( randR + randS >= 1 )
    {
        randR = 1.0 - randR
        randS = 1.0 - randS
    }    
    origin[0]= X_A + randR * ( X_B - X_A ) + randS * ( X_C - X_A )
    origin[1]= Y_A + randR * ( Y_B - Y_A ) + randS * ( Y_C - Y_A )
    
    // To make sure model is at the good altitude on "rock" zone
    if ( ( origin[0] < -847.0 ) && ( origin[1] > -400 ) && ( origin[1] < -100 ) )
        origin[2] = Z_MAX
    else
        origin[2] = Z_MIN

    lastOrigin[0] = origin[0]
    lastOrigin[1] = origin[1]
    lastOrigin[2] = origin[2]
    LOG_EXTRA "get_random_origin [%f,%f,%f]", origin[0], origin[1], origin[2])
    return PLUGIN_CONTINUE
}

public get_random_angle_hostage(Float:angles[])
{
    angles[0] = 0.0
    angles[1] = random_float(-90.0, 90.0)
    angles[2] = 0.0
    LOG_EXTRA "get_random_angle_hostage [%f,%f,%f]", angles[0], angles[1], angles[2])
    return PLUGIN_CONTINUE
}

public Float:get_min_time()
{
    return MIN_TIME/TIME_ACCELERATOR
}

public Float:get_max_bonus_time()
{
    return (MIN_TIME+MAX_TIME_BONUS)/TIME_ACCELERATOR
}

public Float:get_max_time()
{
    return (MIN_TIME+MAX_TIME)/TIME_ACCELERATOR
}

public Float:get_rand_time_extra()
{
    new Float:maxTime
    if ( bonus == BONUS_VALUE )
        maxTime = get_max_bonus_time()
    else
        maxTime = get_max_time()
    return random_float(get_min_time(), maxTime)
}

// Start target spawning
public start_extra()
{
    LOG_EXTRA "start_extra - IN")

    new Float:origin[3]
    new Float:angles[3]
    
    get_random_origin(origin)
    get_random_angle_hostage(angles)

    give_all_max_money()
    
    create_hostage(origin, angles)
    
    new Float:rand = get_rand_time_extra()
    
    LOG_EXTRA "start_extra - %f ", rand)
    if ( stop_enabled != 1 )
        set_task(rand, "hostage_notkilled", NOTKILL_TASK)

    LOG_EXTRA "start_extra - OUT")
    return PLUGIN_CONTINUE    
}

// Punis user on missed target
public punish_user(id)
{
    LOG_EXTRA "punish_user %d", id)
    if ( ( immunity[id] == 0 ) && ( zone[id] == 1 ) )
    {
        new health = get_user_health(id) - HP_PUNISHMENT
        new Float:Xpos = 0.25
        new Float:Ypos = 0.55
        if ( health <= 0 )
        {
            client_cmd(id, MISS_SPK_ZERO)
        }
        else if ( ( health > 0 ) && ( health <= HP_PUNISHMENT ) )
        {
            client_cmd(id, MISS_SPK_LOW_1)
            set_hudmessage(255, 0, 0, Xpos, Ypos, 0, 0.5, 2.0 , 0.5, 0.5, 7)
            show_hudmessage(id, _T("Last chance !!!", id))
        }    
        else if ( ( health > HP_PUNISHMENT ) && ( health <= HP_PUNISHMENT + 5 ) )
        {
            client_cmd(id, MISS_SPK_LOW_2)
            set_hudmessage(255, 0, 0, Xpos, Ypos, 0, 0.5, 2.0 , 0.5, 0.5, 7)
            show_hudmessage(id, _T("You're not far from death !!!", id))
        }
        else if ( ( health > HP_PUNISHMENT + 5 ) && ( health <= HP_PUNISHMENT + 15 ) )
        {
            client_cmd(id, MISS_SPK_LOW_3)
            set_hudmessage(255, 0, 0, Xpos, Ypos, 0, 0.5, 2.0 , 0.5, 0.5, 7)
            show_hudmessage(id, _T("Your HPs are really low !!!", id))
        }
        else
            client_cmd(id, MISS_SPK_LOW_4)
        LOG_EXTRA "punish_user %d - set_user_health = %d", id, health)
        set_user_health(id, health)
        scores[id]      -= SCORE_PUNISHMENT
        totalScores[id] -= SCORE_PUNISHMENT
        new value = SCORE_PUNISHMENT
        if ( value > 0 ) 
        {
            update_realScore(id)
            new temp2[100]
            format(temp2, 99,"-%d point(s) %s %s", SCORE_PUNISHMENT, _T("for", id), _T(" all", id))
            set_hudmessage(255, 0, 0, Xpos, Ypos, 0, 0.5, 1.0 , 0.5, 0.5, 7)
            show_hudmessage(id, temp2)
        }
    }
    else
    {
        LOG_EXTRA "punish_user %d - immunity = %d", id, immunity[id])
        LOG_EXTRA "punish_user %d -     zone = %d", id, zone[id])
    }
    return PLUGIN_CONTINUE
}

// Make everybody rich
public give_all_max_money()
{
    for ( new iz = 1 ; iz < 33 ; iz++ )
    {
        if ( is_user_connected(iz) )
            if ( is_user_alive(iz) )
            {
                LOG_EXTRA "give_all_max_money - %d -> 16000$", iz)
                set_user_money(iz, 16000)
            }
    }    
}

// Target missed by all players
public hostage_notkilled()
{
    LOG_EXTRA "hostage_notkilled - IN")
    if ( lastEntity != 0 )
    {
        LOG_EXTRA "hostage_notkilled - remove_entity %d", lastEntity)
        remove_entity(lastEntity)
        LOG_EXTRA "hostage_notkilled - remove_entity OK")
        lastEntity = 0

        for ( new p = 1 ; p < 33 ; p++ )
        {
            if ( is_user_connected(p) )
                if ( !is_user_bot(p) )
                {
                    new vec[3]
                    vec[0] = floatround(lastOrigin[0])
                    vec[1] = floatround(lastOrigin[1])
                    vec[2] = floatround(lastOrigin[2])-30
                    //vec[2] = -500
                    /* Daredevil effect */
                    message_begin(MSG_ONE, SVC_TEMPENTITY, vec, p)  
                    write_byte(21)
                    write_coord(vec[0])
                    write_coord(vec[1])
                    write_coord(vec[2] + 16)
                    write_coord(vec[0])
                    write_coord(vec[1])
                    write_coord(vec[2] + 400)
                    write_short(spriteWhite)
                    write_byte(0)
                    write_byte(1)
                    write_byte(6)
                    write_byte(8)
                    write_byte(1)
                    write_byte(100)
                    write_byte(100)
                    write_byte(255)
                    write_byte(192)
                    write_byte(0)
                    message_end()
                }
        }
    }
    for ( new user = 1 ; user < 33 ; user++ )
    {
        if ( is_user_connected(user) )
            if ( ! is_user_bot(user) )
                if ( is_user_alive(user) )
                    punish_user(user)
    }
    
    new Float:rand = get_rand_time_extra()
    
    LOG_EXTRA "hostage_notkilled - OUT - %f", rand)
    set_task(rand, "start_extra", NEWEXTRA_TASK)
}

// To check target touched by "extrame" player
public entity_touch(entity1, entity2)
{
    // No entity
    if ( lastEntity == 0 )
        return
    // Useless
    if ( entity1 != lastEntity )
        return
    // Not a player
    if ( !is_player(entity2) )
        return
    
    LOG_EXTRA "entity_touch %d - %d", entity1, entity2)
    
    LOG_EXTRA "entity_touch - remove_entity %d", lastEntity)
    remove_entity(lastEntity)
    LOG_EXTRA "entity_touch - remove_entity OK")
    lastEntity = 0        
    new id = entity2
    client_cmd(id, "stopsound")
    if ( bonus == BONUS_VALUE )
    {
        LOG_EXTRA "entity_touch - %s", BONUS_SPK_2)
        client_cmd(id, BONUS_SPK_2)
    }
    else if ( bonus == BONUS_HOSTAGE )
    {
        LOG_EXTRA "entity_touch - %s", TOUCH_HOSTAGE1_SPK)
        client_cmd(id, TOUCH_HOSTAGE1_SPK)
    }
    else
    {
        LOG_EXTRA "entity_touch - %s", TOUCH_HOSTAGE2_SPK)
        client_cmd(id, TOUCH_HOSTAGE2_SPK)
    }
    new temp[100]
    new eName[32]
    get_user_name(id,eName,31)
    for ( new n = 1 ; n < 33 ; n ++ )
    {            
        if ( is_user_connected(n) )
        {
            if ( ! is_user_bot(n) )
            {
                format(temp, 99, "+%d point(s) %s %s ( %s )", BONUS_ZONE0, _T("for", n), eName, _T("Target touched", n) )
                set_hudmessage( 255, 255, 255, 0.6, 0.6, 0, 0.5, 1.0 , 0.5, 0.5, 8 )
                show_hudmessage(n, temp )
            }
        }
    }
    scores[id]      += BONUS_ZONE0
    totalScores[id] += BONUS_ZONE0
    update_realScore(id)
    update_rankings(id)
    LOG_EXTRA "entity_touch by %d : score = %s", id, scores[id])
    for ( new n = 1 ; n < 33 ; n ++ )
    {            
        if ( is_user_connected(n) )
        {
            if ( ! is_user_bot(n) )
            {
                showScores(n)
            }
        }
    }
}

// Target shot
public host_killed(id)
{
    LOG_EXTRA "host_killed %d - IN", id)
    scores[id]      += 1 + bonus
    totalScores[id] += 1 + bonus
    update_realScore(id)
    update_rankings(id)
    new done = 0
    new name[32], temp[100]
    get_user_name(id, name, 31)
    LOG_EXTRA_ "host_killed by %d, %s", id, name)
    
    if ( bonus == BONUS_VALUE )
    {
        client_print(id, print_center, _T("You killed the chicken !!!", id))
    }
    else
    {
        client_print(id, print_center, _T("You killed the target !", id))
    }

    for ( new n = 1 ; n < 33 ; n ++ )
    {            
        if ( is_user_connected(n) )
        {
            if ( ! is_user_bot(n) )
            {
                format(temp, 99,"+%d point(s) %s %s", 1 + bonus, _T("for", n), name)
                set_hudmessage(255, 255, 255, 0.6, 0.6, 0, 0.5, 1.0 , 0.5, 0.5, 7)
                show_hudmessage(n, temp)
            }
        }
    }
    immunity[id] = 0
    if ( scores[id] > lastHighScore )
    {
        lastHighScore = scores[id]
        new saveString[100]
        format(saveString, 99 ,"%d ^"%s^"", lastHighScore, name)
        write_file(extra_file, saveString, 1) 
        done++
    }
    for ( new n = 1 ; n < 33 ; n ++ )
    {            
        if ( is_user_connected(n) )
        {
            if ( ! is_user_bot(n) )
            {
                format(HighScore, 99 ,FORMAT_HIGHSCORE , _T(BEST_SCORE,n), name, lastHighScore)
                showScores(n)
            }
        }
    }
    if ( bonus == BONUS_VALUE )
    {
        new health = get_user_health(id) + 2*HP_PUNISHMENT
        if ( health < 100 )
            set_user_health(id, health)
        else
            set_user_health(id, 100)
        if ( done == 0 )
            client_cmd(id, BONUS_KILLED_SPK)
        if ( lastEntity != 0 )
        {
            entity_set_model(lastEntity, DEADBONUS_MDL)
            entity_set_int(lastEntity, EV_INT_solid, SOLID_SLIDEBOX)
            entity_set_string(lastEntity, EV_SZ_classname, "bonus_mort")  
            new Float:anglesEnt[3]
            entity_get_vector(lastEntity, EV_VEC_angles, anglesEnt)
            new Float:ranAngle  = random_float(0.0, 359.9)
            new Float:ranAngle2 = random_float(-5.0, 5.0)
            anglesEnt[0] += ranAngle2
            anglesEnt[1] += ranAngle
            entity_set_vector(lastEntity, EV_VEC_angles, anglesEnt);
            update_listBonus(lastEntity)
            
            /* Staying alive */
            lastEntity = 0
        }    
    }
    else
    {
        new health = get_user_health(id) + HP_PUNISHMENT
        if ( health < 100 )
            set_user_health(id, health)
        else
            set_user_health(id, 100)
        client_cmd(id, HOSTAGE_KILLED_SPK)
        LOG_EXTRA "host_killed - cvar keep_hostage = %d", HOSTAGEDEAD_KEEP)
        if ( ( HOSTAGEDEAD_KEEP == 1 ) && ( lastEntity != 0 ) )
        {
            entity_set_model(lastEntity, HOSTAGEDEAD_MDL)
            entity_set_int(lastEntity, EV_INT_solid, SOLID_SLIDEBOX)
            entity_set_string(lastEntity, EV_SZ_classname, "otage_mort") 
            new Float:anglesEnt[3]
            entity_get_vector(lastEntity, EV_VEC_angles, anglesEnt);
            new Float:ranAngle = random_float(0.0, 359.9)
            new Float:ranAngle2 = random_float(-5.0, 5.0)
            anglesEnt[0] += ranAngle2
            anglesEnt[1] += ranAngle
            entity_set_vector(lastEntity, EV_VEC_angles, anglesEnt);
            update_listHostage(lastEntity)
            
            /* Staying alive */
            lastEntity = 0
        }
    }
    LOG_EXTRA "host_killed - lastEntity = %d", lastEntity)
    kill_tasks()
    
    new Float:rand = get_rand_time_extra()
    
    set_task(rand, "start_extra", NEWEXTRA_TASK)
    LOG_EXTRA "host_killed - start_extra %f", rand)
    LOG_EXTRA_ "host_killed by %d : score = %d", id, scores[id])
    LOG_EXTRA "host_killed %d - OUT", id)
    return PLUGIN_HANDLED_MAIN
} 

public showScores(id)
{
    new message[2048],temp[64],message2[512]
    format(message, 511, " - %s -", _T("Extra scores", id))
    add(message, 2048, "^n^n")
    add(message, 2048, HighScore)
    add(message, 2048, "^n")
    new n = 0
    for ( new x = 1 ; x < 33 ; x++ )
    {
        if ( ranking[x] > 0 )
        {
            if ( n == 0 )
            {
                format(message2, 511, "^n%s :^n", _T("Round rankings", id))
                add(message, 2048, message2)
            }
            n++
            new name[32]
            get_user_name(ranking[x], name, 31) 
            format(temp, 64, "^n %d - %s ( %d )", x, name, scores[x])
            add(message, 2048, temp)
        }
        else
            break
    }
    set_hudmessage(255, 255, 255, 0.05, 0.4, 0, 0.5, 3.0 , 0.5, 0.5, 5)
    if ( n > 0 ) 
        show_hudmessage(id, message)
}

public kill_tasks()
{
    LOG_EXTRA "kill_tasks - IN")
    if ( task_exists (NOTKILL_TASK) )
    {
        LOG_EXTRA "kill_tasks - remove_task %d", NOTKILL_TASK)
        remove_task(NOTKILL_TASK)
    }
    if ( task_exists(NEWEXTRA_TASK) )
    {
        LOG_EXTRA "kill_tasks - remove_task %d", NEWEXTRA_TASK)
        remove_task(NEWEXTRA_TASK)
    }
    LOG_EXTRA "kill_tasks - OUT")
}

// Get player speed back to normal
public decelerate(id)
{
    LOG_EXTRA "decelerate %d", id)
    set_user_gravity(id)
    set_user_maxspeed(id)
    return PLUGIN_CONTINUE
}

// Set "extrame" player speed
public set_extra_speed(id)
{
    LOG_EXTRA "set_extra_speed %d", id)
    set_user_gravity(id, 0.2)
    client_cmd(id, "cl_forwardspeed %s; cl_sidespeed %s; cl_backspeed %s", EXTRA_SPEED, EXTRA_SPEED, EXTRA_SPEED)
    set_user_maxspeed(id, EXTRA_FSPEED)
}

public accelerate(id)
{
    LOG_EXTRA "accelerate %d", id)
    set_extra_speed(id)
    return PLUGIN_CONTINUE
}

// Modify message on hostage injured
public event_HostageInjured(const iMsgID, const iMsgDest, id)
{
    new hostInjuredStr[20]
    get_msg_arg_string(2, hostInjuredStr, charsmax(hostInjuredStr))
    if(id && equal(hostInjuredStr, "#Injured_Hostage") )
    {
        set_hudmessage(255, 0, 0, 0.52, 0.52, 0, 0.5, 0.3, 0.1, 0.1, 8)
        if ( zone[id] == 1 )
            show_hudmessage(id, _T("Almost ...", id))
        else
            show_hudmessage(id, _T("More points by touching target !!!", id))
        return PLUGIN_HANDLED_MAIN
    }
    return PLUGIN_CONTINUE
}

// Modify message on aimed target
public event_StatusValue(const iMsgID, const iMsgDest, id)
{
    if(id && get_msg_arg_int(1) == 1 && get_msg_arg_int(2) == 3)
    {
        set_hudmessage(255, 0, 0, 0.52, 0.52, 0, 0.5, 0.3, 0.1, 0.1, 8)
        if ( zone[id] == 1 )
            show_hudmessage(id, _T("Shoot !!!", id))
        else
            show_hudmessage(id, _T("Run to the target !!!", id))
        return PLUGIN_HANDLED_MAIN
    }
    return PLUGIN_CONTINUE
}

// Drop weapons of "extrame" player after first shoot
public event_CurWeapon(id)
{
    if ( zone[id] == 0 )
    {
        new weapon = read_data(2)
        if ( weapon != 29 ) // Knife
        {
            // Drop user gun  ... ^^ ...
            fm_strip_user_gun(id)
        }
        set_extra_speed(id)
    }
}

// Round start
public extra_beginning()
{
    LOG_EXTRA "extra_beginning - IN")

    bonus = 0
    lastEntity = 0
    stop_enabled = 0
    kill_tasks()
    show_beginning(0)
    give_all_max_money()
    for ( new c = 1 ; c < 33 ; c++ )
    {
        ranking[c] = 0
        if ( is_user_connected(c) )
            if ( is_user_alive(c) )
                if ( !is_user_bot(c) )
                {
                    immunity[c] = 0
                    zone[c] = 1
                }
    }
    
    set_task(START_DELAY, "start_extra", NEWEXTRA_TASK)
    LOG_EXTRA "extra_beginning - start_extra %f", START_DELAY)

    LOG_EXTRA "extra_beginning - OUT")
}

// Round end
public extra_stop()
{
    LOG_EXTRA "extra_stop - IN")
    stop_enabled = 1
    kill_tasks()
    if ( lastEntity != 0 )
    {
        LOG_EXTRA "extra_stop - remove_entity %d", lastEntity)
        remove_entity(lastEntity)
        LOG_EXTRA "extra_stop - remove_entity OK")
        lastEntity = 0
    }
    bonus = 0
    for ( new n = 1 ; n < 33 ; n ++ )
    {
        ranking[n] = 0
        if ( is_user_connected(n) )
        {
            if ( ! is_user_bot(n) )
            {
                showScores(n)
                immunity[n] = 1
            }
        }
    }
    
    LOG_EXTRA "extra_stop - OUT")
    return PLUGIN_HANDLED
}

// Starting round message
public show_beginning(id)
{
    new temp[128]
    format(temp, 127, "^n%s !!!^n^n%s ...", _T("Prepare your weapons", id), _T("Don't miss the targets", id) )
    set_hudmessage(255, 255, 255, -1.0, 0.3, 0, 0.5, 3.0 , 0.5, 0.5, 7)
    show_hudmessage(id, temp)
}

public new_round( id )
{
    LOG_EXTRA "new_round - %d - IN", id)
    if ( lastEntity != 0 )
    {
        LOG_EXTRA "new_round - remove_entity %d", lastEntity)
        remove_entity(lastEntity)
        LOG_EXTRA "new_round - remove_entity OK")
        lastEntity = 0
    }
    scores[id] = 0
    if ( ! is_user_bot(id) )
    {
        zone[id] = 1
        show_beginning(id)
    }
    LOG_EXTRA "new_round - %d - OUT", id)
}

// To reset best score on server
public resetHighScore(id, level, cid) 
{
    LOG_EXTRA "resetHighScore - IN")
    if (!cmd_access(id, level, cid, 0)) 
        return PLUGIN_CONTINUE 
    lastHighScore = 0
    format(HighScore, 99, _T(FORMAT_NOHIGHSCORE))
    write_file(extra_file, "// High score", 0)
    write_file(extra_file, "0 ^"???^"", 1)
    new temp[64]
    for ( new c = 1 ; c < 33 ; c++ )
    {
        if ( is_user_connected(c) )
        {
            if ( !is_user_bot(c) )
            {
                format(temp, 63, "* %s", _T("High score resetted by admin", c) )
                client_print(c, print_chat, temp)    
            }
        }
    }
    LOG_EXTRA "resetHighScore - OUT")
    return PLUGIN_HANDLED
}

public get_last_highScore()
{
    LOG_EXTRA "get_last_highScore")
    if ( file_exists(extra_file) ) 
    {
        new text[100],len
        read_file(extra_file, 1, text, 99, len)
        if ( len > 0 )
        {
            new score[33],lastName[33]
            parse(text, score, 32, lastName, 32)
            if ( strtonum(score) == 0 )
            {
                lastHighScore = 0
            }
            else
            {
                lastHighScore = strtonum(score)
            }
        }
        else
        {
            lastHighScore = 0
        }
    }
    else 
    {
        write_file(extra_file, "// High score", 0) 
        write_file(extra_file, "0 ^"???^"", 1) 
    }
    return PLUGIN_CONTINUE
}

// Called on say /extrame
public become_target(id, tk)
{
    LOG_EXTRA "become_target %d-%d - IN", id, tk)
    if ( zone[id] == 1 )
    {
        if ( tk != 1 )
        {
            fm_strip_user_gun(id)
            set_task(0.5, "move_zone", id)
        }
        else
        {
            // Drop user gun
            fm_strip_user_gun(id)
            set_task(0.1, "move_zone", id)
        }
        set_task(0.1, "print_msgTarget", id)
    }
    LOG_EXTRA "become_target %d-%d - OUT", id, tk)
}

// Message for the new "extrame" player
public print_msgTarget(id)
{
    //client_print(id, print_chat, "* %s !!!", _T("You are now a target", id) )
    set_hudmessage(255, 0, 0, 0.52, 0.52, 0, 0.5, 2.0 , 0.5, 0.5, 8)
    show_hudmessage(id, _T("You are now a target", id))
}

// To check frags between players and turn them targets ...
public made_frag(id)
{
    new killer  = read_data(1) 
    new victim  = read_data(2) 
    LOG_EXTRA_ "made_frag k:%d v:%d", killer, victim)
    
    if ( ( killer == 0 ) || ( victim == 0 ) )
        return PLUGIN_CONTINUE 
    if ( killer == victim )
        return PLUGIN_CONTINUE 
    
    if ( ( zone[victim] == 1 ) && ( zone[killer] == 1 ) )
    {
        new temp[100]
        for ( new v = 1 ; v < 33 ; v ++ )
        {
            if ( is_user_connected(v) )
            {
                if ( ! is_user_bot(v) )
                {
                    LOG_EXTRA "made_frag TK")
                    format(temp, 99, "^n%s !!!^n^n+%d point(s) %s ...", _T("TK is bad", v), BONUS_ZONE0, _T("for the death of a TeamKiller", v) )
                    set_hudmessage(255, 255, 255, -1.0, 0.3, 0, 0.5, 3.0 , 0.5, 0.5, 7)
                    show_hudmessage(v, temp)
                }
            }
        }
        LOG_EXTRA "made_frag TK")
        client_cmd(id, "drop;wait;wait;wait;drop;wait;wait;wait;drop")
        become_target(killer, 1)
        set_task(0.1, "respawn", victim)
    }
    else if ( ( zone[victim] == 1 ) && ( zone[killer] == 0 ) )
    {
        LOG_EXTRA "made_frag TARGET")
        set_hudmessage(255, 255, 255, -1.0, 0.3, 0, 0.5, 3.0 , 0.5, 0.5, 7)
        new msg[128]
        format(msg, 127, "^n%s ...^n^n%s !!!", _T("You've been killed by a target", victim), _T("Owned", victim) )
        show_hudmessage(victim, msg)
        
        scores[killer]         += BONUS_ZONE0
        totalScores[killer]    += BONUS_ZONE0
        update_realScore(killer)
    }
    else if ( zone[victim] == 0 )
    {
        new temp[100]
        if ( ! is_user_bot(victim) )
        {
            if ( ! is_user_bot(killer) )
            {
                scores[killer]         += BONUS_ZONE0
                totalScores[killer]    += BONUS_ZONE0
                update_realScore(killer)
            }
        }
        else
        {
            if ( ! is_user_bot(killer) )
            {
                scores[killer]         += BONUS_BOT
                totalScores[killer]    += BONUS_BOT
                update_realScore(killer)
            }
        }
        new name[32]
        get_user_name(killer, name, 31) 
        if ( ! is_user_bot(victim) )
        {
            deads[victim] += 1
            update_realScore(victim)
            for ( new v = 1 ; v < 33 ; v ++ )
            {    
                if ( is_user_connected(v) )
                {
                    if ( ! is_user_bot(v) )
                    {
                        format(temp, 99, "+%d point(s) %s %s ( %s )", BONUS_ZONE0, _T("for", v), name, _T("Death of a TeamKiller", v))
                        set_hudmessage(255, 255, 255, 0.6, 0.6, 0, 0.5, 1.0 , 0.5, 0.5, 8)
                        show_hudmessage(v, temp)
                    }
                }
            }
        }
        else
        {
            for ( new v = 1 ; v < 33 ; v ++ )
            {    
                if ( is_user_connected(v) )
                {
                    if ( ! is_user_bot(v) )
                    {
                        format(temp, 99,"+%d point(s) %s %s ( %s )", BONUS_BOT, _T("for", v), name, _T("Death of a Bot", v))
                        set_hudmessage(255, 255, 255, 0.6, 0.6, 0, 0.5, 1.0 , 0.5, 0.5, 8)
                        show_hudmessage(v, temp)
                    }
                }
            }
        }
        
        if ( ! is_user_bot(killer) )
            update_rankings(killer)
            
        for ( new n = 1 ; n < 33 ; n ++ )
        {            
            if ( is_user_connected(n) )
            {
                if ( ! is_user_bot(n) )
                {
                    showScores(n)
                }
            }
        }    
    }
    return PLUGIN_CONTINUE 
}

// To call delayed spawn
public respawn( id ) 
{
    LOG_EXTRA "respawn %d", id)
    user_spawn( id )
}

// Update ScoreBoard
public update_realScore(id)
{
    LOG_EXTRA "update_realScore %d", id)
    message_begin(MSG_ALL, get_user_msgid("ScoreInfo"))
    write_byte(id)
    write_short(totalScores[id])
    write_short(deads[id])
    write_short(0)
    write_short(get_user_team(id))
    message_end()    
}

new spawn_target_zone = 1 // Index to use a new "hidden" spawn position for "extrame" player

public move_zone(id)
{
    LOG_EXTRA "move_zone - id %d", id)
    if ( zone[id] == 1 )
    {
        LOG_EXTRA "move_zone - zone 0")
        zone[id] = 0
        new orig[3]
        get_user_origin(id, orig)
        // Hidden point
        if ( spawn_target_zone < 5 ) 
        {
            orig[0] = -1140-(spawn_target_zone-1)*40
            orig[1] =  -250
        }
        else if ( spawn_target_zone < 7 )
        {
            orig[0] = -800-(spawn_target_zone-5)*40
            orig[1] =  450
        }
        else if ( spawn_target_zone < 9 )
        {
            orig[0] = -540-(spawn_target_zone-7)*40
            orig[1] = -940
        }
        else
        {
            orig[0] = -1140-(spawn_target_zone-9)*40
            orig[1] =  -250
        }
        spawn_target_zone += 1
        if ( spawn_target_zone > 10 )
            spawn_target_zone = 1
            
        set_user_origin(id, orig)
    }
    set_task(2.0, "accelerate", id)
}

//-------------- Initialisations --------------//

public plugin_init()
{
    register_plugin("Awp Map Extra", "2014.1.0", "DanRaZor")
    LOG_EXTRA "plugin_init")

    load_translations(translator_file)

    cvarPointerAccel = register_cvar("amx_awp_extra_accelerator",  "1.0")   // Speed, use 0.4 ( faster ) to 2.0 ( lower )
    cvarPointerKeepH = register_cvar("amx_awp_extra_keep_hostage", "1")     // Leave an entity on target killed : 1 or not : 0
    cvarPointerLight = register_cvar("amx_awp_extra_light",        "f")     // Ambient light to add difficulty
    
    if ( map_is_awp_map() ) 
    {
        register_logevent("extra_beginning", 2, "0=World triggered", "1=Round_Start")
            
        register_event("ResetHUD", "new_round", "b")
        register_event("SendAudio", "extra_stop", "a", "2=%!MRAD_terwin", "2=%!MRAD_ctwin", "2=%!MRAD_rounddraw")
        register_event("TextMsg", "host_killed", "b", "2&#Killed_Hostage") 
        register_event("DeathMsg", "made_frag", "a") 
        register_event("CurWeapon" , "event_CurWeapon" , "be" , "1=1" )
        
        register_message(get_user_msgid("StatusValue"), "event_StatusValue")
        register_message(get_user_msgid("TextMsg"), "event_HostageInjured") 
            
        register_concmd("amx_resetExtraScore", "resetHighScore", ADMIN_RCON, _T("Resets the extra HighScore"))
        
        register_clcmd("say /extrame", "become_target", 0, _T("To become a target ..."))
        
        set_msg_block(get_user_msgid("ScoreInfo"), BLOCK_SET)
    }
}

// Where it all starts ...
public plugin_cfg()
{
    if ( map_is_awp_map() ) 
    {
        LOG_EXTRA "plugin_cfg")
        lastEntity = 0
        for ( new y =0 ; y < NB_BONUS_MAX ; y++)
            tabEntBonus[y] = 0
        for ( new z =0 ; z < NB_HOSTAGE_MAX ; z++)
            tabEntHostage[z] = 0
        for ( new x =0 ; x < 33 ; x++ )
        {
            scores[x]      = 0
            totalScores[x] = 0
            deads[x]       = 0
            ranking[x]     = 0
        }

        // Spawn "corrections"
        remove_weapons()
        move_t_spawns()
        move_ct_spawns()
        
        // Add banner and barrier
        add_entities()
        
        // Zone control
        start_player_control()

        // Sky
        set_cvar_string("sv_skyname", "backalley")
        LOG_EXTRA "plugin_cfg - sv_skyname = backalley")
        
        // Light
        new lightValue[10]
        get_cvarptr_string(cvarPointerLight, lightValue, charsmax(lightValue))
        set_lights(lightValue)

        // High score update
        get_last_highScore()
     
        // Rankings reset
        for ( new z = 1 ; z < 33 ; ++z )
        {
            ranking[z] = 0
        }
    }
    return PLUGIN_CONTINUE
}

plugin_end()
{
    if ( map_is_awp_map() ) 
    {
        LOG_EXTRA "plugin_end")
        // On deactivation of plugin ... Nothing to do here
    }
    return PLUGIN_CONTINUE
}

// Useful to not lose debug log on restart ...
public rename_log()
{
    // Move log file
    new current_time[20]
    get_time("%d%m%Y_%H%M%S", current_time, charsmax(current_time))
    new log_file_path[100]
    format(log_file_path, charsmax(log_file_path), "addons/amx/logs/%s", LOG_FILE)
    if ( file_exists(log_file_path) )
    {
        new new_log_file[100]
        format(new_log_file, charsmax(new_log_file), "addons/amx/logs/%s_%s", current_time, LOG_FILE)
        // Move previous file
        new text[256]
        new len, pos = 0
        while( ( pos = read_file(log_file_path, pos, text, charsmax(text), len) ) ) {
            write_file(new_log_file, text)
        }
        // Delete old file
        delete_file(log_file_path)
    }
}

public plugin_precache( )
{
    if ( map_is_awp_map() ) 
    {
        rename_log()
    
        LOG_EXTRA "plugin_precache - models")
        // Models
        precache_model(BARRIER_MDL)
        new szModel[24]
        new indexHos = 1
        format(szModel, charsmax(szModel), HOSTAGE_FORMAT, indexHos)
        precache_model(szModel)
        indexHos = 2
        format(szModel, charsmax(szModel), HOSTAGE_FORMAT, indexHos)
        precache_model(szModel)
        precache_model(BONUS_MDL)
        precache_model(DEADBONUS_MDL)
        precache_model(BANNER_MDL)
        precache_model(HOSTAGEDEAD_MDL)
        
        LOG_EXTRA "plugin_precache - precache_sound %s", BONUS_SOUND)
        precache_sound(BONUS_SOUND)
        LOG_EXTRA "plugin_precache - precache_sound %s", BONUS_T_SOUND)
        precache_sound(BONUS_T_SOUND)

        LOG_EXTRA "plugin_precache - white sprite")
        // Daredevil effect
        spriteWhite = precache_model("sprites/white.spr")

        // Hostage spawning
        LOG_EXTRA "plugin_precache - hostage sounds")
        precache_sound("hostage/hos1.wav")
        precache_sound("hostage/hos2.wav")
        precache_sound("hostage/hos3.wav")
        precache_sound("hostage/hos4.wav")
        precache_sound("hostage/hos5.wav")

        // Sky 
        LOG_EXTRA "plugin_precache - sky map")
        precache_generic("gfx/env/backalleyup.tga")
        precache_generic("gfx/env/backalleydn.tga")
        precache_generic("gfx/env/backalleyft.tga")
        precache_generic("gfx/env/backalleybk.tga")
        precache_generic("gfx/env/backalleylf.tga")
        precache_generic("gfx/env/backalleyrt.tga")
    }
}

//--------------     The End     --------------//