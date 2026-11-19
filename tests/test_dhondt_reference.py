def dhondt(votes, seats, valid_votes, threshold=0.03):
    result = {p: 0 for p in votes}
    eligible = sorted(p for p, v in votes.items() if valid_votes and v / valid_votes >= threshold)
    for _ in range(seats):
        if not eligible:
            break
        winner = max(eligible, key=lambda p: (votes[p] / (result[p] + 1), votes[p], -ord(p[0])))
        result[winner] += 1
    return result

assert dhondt({"A": 1000, "B": 600, "C": 300}, 5, 1900, 0.03) == {"A": 3, "B": 2, "C": 0}
print("OK: prueba básica D'Hondt.")
