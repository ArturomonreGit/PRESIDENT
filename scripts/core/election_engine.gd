extends RefCounted
class_name ElectionEngine

## Reparto D'Hondt por circunscripción.
## Los votos válidos incluyen votos a candidaturas y votos en blanco.
## El umbral legal del Congreso se aplica por circunscripción (3%).
## En empates exactos de cociente, esta primera versión usa orden estable por ID
## para garantizar reproducibilidad. La casuística legal de desempate se revisará
## contra actas oficiales antes de considerar el motor certificado.

static func dhondt(votes_by_party: Dictionary, seats: int, valid_votes: int, threshold: float = 0.03) -> Dictionary:
	var result: Dictionary = {}
	if seats <= 0:
		return result

	var eligible: Array[String] = []
	for party_id in votes_by_party.keys():
		var votes: int = int(votes_by_party[party_id])
		if valid_votes > 0 and float(votes) / float(valid_votes) >= threshold:
			eligible.append(str(party_id))
		result[str(party_id)] = 0

	eligible.sort()
	for _seat in range(seats):
		var best_party := ""
		var best_quotient := -1.0
		var best_votes := -1

		for party_id in eligible:
			var votes: int = int(votes_by_party[party_id])
			var quotient: float = float(votes) / float(int(result[party_id]) + 1)
			if quotient > best_quotient:
				best_quotient = quotient
				best_votes = votes
				best_party = party_id
			elif is_equal_approx(quotient, best_quotient):
				if votes > best_votes:
					best_votes = votes
					best_party = party_id
				elif votes == best_votes and (best_party == "" or party_id < best_party):
					best_party = party_id

		if best_party == "":
			break
		result[best_party] = int(result[best_party]) + 1

	return result


static func calculate_national_seats(constituencies: Array, votes_by_constituency: Dictionary, threshold: float = 0.03, blank_votes_by_constituency: Dictionary = {}) -> Dictionary:
	var totals: Dictionary = {}
	var details: Dictionary = {}

	for constituency in constituencies:
		var cid: String = str(constituency.get("id", ""))
		var seats: int = int(constituency.get("seats", 0))
		var votes: Dictionary = votes_by_constituency.get(cid, {})
		var valid_votes := 0
		for value in votes.values():
			valid_votes += int(value)
		# La LOREG define votos válidos como votos a candidaturas + votos en blanco.
		valid_votes += int(blank_votes_by_constituency.get(cid, 0))

		var allocation := dhondt(votes, seats, valid_votes, threshold)
		details[cid] = allocation
		for party_id in allocation.keys():
			totals[party_id] = int(totals.get(party_id, 0)) + int(allocation[party_id])

	return {"totals": totals, "by_constituency": details}


static func total_seats(allocation: Dictionary) -> int:
	var total := 0
	for value in allocation.values():
		total += int(value)
	return total
