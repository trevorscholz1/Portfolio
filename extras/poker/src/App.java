import java.util.*;

public class App {
    private static int evaluateHand(List<String> hand) {
        String ranks = "23456789TJQKA";
        Map<Character, Integer> values = new HashMap<>();
        for (int i = 0; i < ranks.length(); i++) {
            values.put(ranks.charAt(i), i);
        }
        hand.sort((a, b) -> values.get(b.charAt(0)) - values.get(a.charAt(0)));
        return values.get(hand.get(0).charAt(0));
    }

    private static double monteCarloSimulation(List<String> holeCards, List<String> communityCards, int numSimulations) {
        String suits = "CDHS";
        String ranks = "23456789TJQKA";
        List<String> deck = new ArrayList<>();
        for (char r : ranks.toCharArray()) {
            for (char s : suits.toCharArray()) {
                deck.add("" + r + s);
            }
        }

        deck.removeAll(holeCards);
        deck.removeAll(communityCards);

        int wins = 0;
        for (int i = 0; i < numSimulations; i++) {
            List<String> remainingDeck = new ArrayList<>(deck);
            Collections.shuffle(remainingDeck);
            List<String> oppHoleCards = Arrays.asList(remainingDeck.remove(0), remainingDeck.remove(0));
            List<String> remainingCommunityCards = new ArrayList<>(communityCards);
            while (remainingCommunityCards.size() < 5) {
                remainingCommunityCards.add(remainingDeck.remove(0));
            }

            List<String> myHand = new ArrayList<>(holeCards);
            myHand.addAll(remainingCommunityCards);
            List<String> oppHand = new ArrayList<>(oppHoleCards);
            oppHand.addAll(remainingCommunityCards);

            if (evaluateHand(myHand) > evaluateHand(oppHand)) {
                wins++;
            }
        }
        return (double) wins / numSimulations;
    }

    private static String makeDecision(List<String> holeCards, List<String> communityCards, int currentBet, int potSize, int numPlayers) {
        double winProbability = monteCarloSimulation(holeCards, communityCards, 1000);

        double callCost = currentBet;
        double potOdds = (double) potSize / callCost;
        double expectedValue = (winProbability * potSize) - ((1 - winProbability) * callCost);

        if (expectedValue < 0) {
            return "Fold";
        } else if (winProbability * potOdds > 1) {
            return "Raise";
        } else {
            return "Call";
        }
    }

    public static void main(String[] args) {
        List<String> holeCards = Arrays.asList("AH", "KS");
        List<String> communityCards = Arrays.asList("2D", "3C", "7H");
        int currentBet = 50;
        int potSize = 150;
        int numPlayers = 3;

        String decision = makeDecision(holeCards, communityCards, currentBet, potSize, numPlayers);
        System.out.println("Decision: " + decision);
    }
}