/mob/proc/can_emote(var/emote_type)
	return (stat == CONSCIOUS)

/mob/living/can_emote(var/emote_type)
	return (..() && !(silent && emote_type == AUDIBLE_MESSAGE))

/mob/verb/custom_audible_emote()
	set name = "Audible Emote"
	set category = "IC"
	set desc = "Type in an emote message that will be received by mobs that can hear you."

	custom_emote(m_type = AUDIBLE_MESSAGE, message = sanitize(input(src,"Choose an emote to display.") as text|null))

/mob/verb/custom_visible_emote()
	set name = "Visible Emote"
	set category = "IC"
	set desc = "Type in an emote message that will be received by mobs that can see you."

	custom_emote(m_type = VISIBLE_MESSAGE, message = sanitize(input(src,"Choose an emote to display.") as text|null))

/mob/proc/emote(var/act, var/m_type, var/message)
	// s-s-snowflake
	if((src.stat == DEAD || src.status_flags & FAKEDEATH) && act != "deathgasp")
		return

	var/splitpoint = findtext(act, " ")
	if(splitpoint > 0)
		var/tempstr = act
		act = copytext(tempstr,1,splitpoint)
		message = copytext(tempstr,splitpoint+1,0)

	var/singleton/emote/use_emote = usable_emotes[act]
	if(!use_emote)
		to_chat(src, SPAN_WARNING("Unknown emote '[act]'. Type <b>say *help</b> for a list of usable emotes."))
		return

	if(m_type && m_type != use_emote.message_type)
		return

	if(!use_emote.can_do_emote(src))
		return

	if(use_emote.message_type == AUDIBLE_MESSAGE && is_muzzled())
		audible_message("<b>\The [src]</b> makes a muffled sound.")
		return
	else
		use_emote.do_emote(src, message)

	for (var/obj/item/implant/I in src)
		if (I.implanted)
			I.trigger(act, src)


/mob/proc/client_emote(var/act, var/m_type, var/message)
	if((src.stat == DEAD || src.status_flags & FAKEDEATH) && act != "deathgasp")
		return

	if(usr == src) //client-called emote
		if (client && (client.prefs.muted & MUTE_IC))
			to_chat(src, "<span class='warning'>You cannot send IC messages (muted).</span>")
			return

		if(act == "help")
			to_chat(src,"<b>Usable emotes:</b> [english_list(usable_emotes)]")
			return

		if(!can_emote(m_type))
			to_chat(src, "<span class='warning'>You cannot currently [m_type == AUDIBLE_MESSAGE ? "audibly" : "visually"] emote!</span>")
			return

		if(act == "me")
			return custom_emote(m_type, message)

		if(act == "custom")
			if(!message)
				message = sanitize(input("Enter an emote to display.") as text|null)
			if(!message)
				return
			if (!m_type)
				if(alert(src, "Is this an audible emote?", "Emote", "Yes", "No") == "No")
					m_type = VISIBLE_MESSAGE
				else
					m_type = AUDIBLE_MESSAGE
			return custom_emote(m_type, message)
	return emote(act)

/mob/proc/format_emote(var/emoter = null, var/message = null)
	var/pretext
	var/subtext
	var/nametext
	var/end_char
	var/start_char
	var/name_anchor
	var/anchor_char = "^"

	if(!message || !emoter)
		return

	message = html_decode(message)

	name_anchor = findtext(message, anchor_char)
	if(name_anchor > 0) // User supplied emote with visible_emote token (default ^)
		pretext = copytext(message, 1, name_anchor)
		subtext = copytext(message, name_anchor + 1, length(message) + 1)
	else
		// No token. Just the emote as usual.
		subtext = message

	// Oh shit, we got this far! Let's see... did the user attempt to use more than one token?
	if(findtext(subtext, anchor_char))
		// abort abort!
		to_chat(emoter, "<span class='warning'>You may use only one \"[anchor_char]\" symbol in your emote.</span>")
		return

	if(pretext)
		// Add a space at the end if we didn't already supply one.
		end_char = copytext(pretext, length(pretext), length(pretext) + 1)
		if(end_char != " ")
			pretext += " "

	// Grab the last character of the emote message.
	end_char = copytext(subtext, length(subtext), length(subtext) + 1)
	if(!(end_char in list(".", "?", "!", "\"", "-", "~"))) // gotta include ~ for all you fucking weebs
		// No punctuation supplied. Tack a period on the end.
		subtext += "."

	// Add a space to the subtext, unless it begins with an apostrophe or comma.
	if(subtext != ".")
		// First, let's get rid of any existing space, to account for sloppy emoters ("X, ^ , Y")
		subtext = trim_left(subtext)
		start_char = copytext(subtext, 1, 2)
		if(start_char != "," && start_char != "'")
			subtext = " " + subtext

	pretext = capitalize(html_encode(pretext))
	nametext = html_encode(nametext)
	subtext = html_encode(subtext)
	// Store the player's name in a nice bold, naturalement
	nametext = "<B>[emoter]</B>"
	return pretext + nametext + subtext

/mob/proc/custom_emote(var/m_type = VISIBLE_MESSAGE, var/message = null, var/do_show_observers = TRUE)

	if((usr && stat) || (!use_me && usr == src))
		to_chat(src, "You are unable to emote.")
		return

	if(!message)
		return

	message = format_emote(src, message)

	if (message)
		log_emote("[name]/[key] : [message]")

	message = process_chat_markup(message, list("~", "_"))
	if(m_type == VISIBLE_MESSAGE)
		visible_message(message, show_observers = do_show_observers)
	else
		audible_message(message, ghost_hearing = do_show_observers)

// Specific mob type exceptions below.
/mob/living/silicon/ai/emote(var/act, var/type, var/message)
	var/obj/machinery/hologram/holopad/T = src.holo
	if(T?.active_holograms[src]) //Is the AI using a holopad?
		src.holopad_emote(message)
	else //Emote normally, then.
		..()

/mob/living/captive_brain/emote(var/message)
	return

/mob/abstract/observer/emote(var/act, var/type, var/message)
	if(!message)
		return

	if(act != "me")
		return

	log_emote("Ghost/[src.key] : [message]",ckey=key_name(src))

	if(src.client)
		if(src.client.prefs.muted & (MUTE_DEADCHAT|MUTE_IC))
			to_chat(src, "<span class='warning'>You cannot emote in deadchat (muted).</span>")
			return

	. = src.emote_dead(message)
