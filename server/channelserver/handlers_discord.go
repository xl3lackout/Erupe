package channelserver

import (
	"fmt"
	"os"
	"time"

	"github.com/bwmarrin/discordgo"
)

// onDiscordMessage handles receiving messages from discord and forwarding them ingame.
func (s *Server) onDiscordMessage(ds *discordgo.Session, m *discordgo.MessageCreate) {
	// Ignore messages from our bot, or ones that are not in the correct channel.
	if m.Author.ID == ds.State.User.ID || m.ChannelID != s.erupeConfig.Discord.ChannelID {
		return
	}

	message := fmt.Sprintf("[DISCORD] %s: %s", m.Author.Username, m.Content)
	s.BroadcastChatMessage(message)
}

func dayConvert(result string) string {
	var replaceDays string

	if result == "1" {
		replaceDays = "Lundi"
	} else if result == "2" {
		replaceDays = "Mardi"
	} else if result == "3" {
		replaceDays = "Mercredi"
	} else if result == "4" {
		replaceDays = "Jeudi"
	} else if result == "5" {
		replaceDays = "Vendredi"
	} else if result == "6" {
		replaceDays = "Samedi"
	} else if result == "7" {
		replaceDays = "Dimanche"
	} else {
		replaceDays = "NULL"
	}

	return replaceDays
}

func MonthConvert(result string) string {
	var replaceMonth string

	if result == "01" {
		replaceMonth = "Janvier"
	} else if result == "02" {
		replaceMonth = "Fevrier"
	} else if result == "03" {
		replaceMonth = "Mars"
	} else if result == "04" {
		replaceMonth = "Avril"
	} else if result == "05" {
		replaceMonth = "Mai"
	} else if result == "06" {
		replaceMonth = "Juin"
	} else if result == "07" {
		replaceMonth = "Juillet"
	} else if result == "08" {
		replaceMonth = "Aout"
	} else if result == "09" {
		replaceMonth = "Septembre"
	} else if result == "10" {
		replaceMonth = "Octobre"
	} else if result == "11" {
		replaceMonth = "Novembre"
	} else if result == "12" {
		replaceMonth = "Decembre"
	} else {
		replaceMonth = "NULL"
	}

	return replaceMonth
}

func (s *Server) TimerUpdate(timer int, typeStop int, disableAutoOff bool) {
	timertotal := 0
	for timer > 0 {
		time.Sleep(1 * time.Minute)
		timer -= 1
		timertotal += 1
		if disableAutoOff {
			// Un message s'affiche toutes les 10 minutes pour prévenir de la maintenance.
			if timertotal == 10 {
				timertotal = 0
				if typeStop == 0 {
					s.BroadcastChatMessage("RAPPEL DE MAINTENANCE DU MARDI (18H-22H): Les serveurs seront")
					s.BroadcastChatMessage(fmt.Sprintf("temporairement inaccessibles dans %d minutes. Veuillez ne pas", timer))
					s.BroadcastChatMessage("vous connecter ou deconnectez-vous maintenant, afin de ne pas")
					s.BroadcastChatMessage("perturber les operations de maintenance. Veuillez nous excuser")
					s.BroadcastChatMessage("pour la gene occasionnee. Merci de votre cooperation.")
				} else {
					s.BroadcastChatMessage("RAPPEL DE MAINTENANCE EXCEPTIONNELLE: Les serveurs seront")
					s.BroadcastChatMessage(fmt.Sprintf("temporairement inaccessibles dans %d minutes. Veuillez ne pas", timer))
					s.BroadcastChatMessage("vous connecter ou deconnectez-vous maintenant, afin de ne pas")
					s.BroadcastChatMessage("perturber les operations de maintenance. Veuillez nous excuser")
					s.BroadcastChatMessage("pour la gene occasionnee. Merci de votre cooperation.")
				}
			}
			// Déconnecter tous les joueurs du serveur.
			if timer == 0 {
				os.Exit(-1)
			}
		}
	}
}
