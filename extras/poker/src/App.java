import java.util.*;

public class App {

    // Helper function to determine the rank value
    private static int rankValue(char rank) {
        String ranks = "23456789TJQKA";
        return ranks.indexOf(rank);
    }

    // Helper function to determine if the hand contains a straight
    private static boolean isStraight(List<Integer> values) {
        Collections.sort(values);
        for (int i = 1; i < values.size(); i++) {
            if (values.get(i) != values.get(i - 1) + 1) {
                return false;
            }
        }
        return true;
    }

    // Helper function to determine if the hand contains a flush
    private static boolean isFlush(List<String> hand) {
        char suit = hand.get(0).charAt(1);
        for (String card : hand) {
            if (card.charAt(1) != suit) {
                return false;
            }
        }
        return true;
    }

    // Helper function to determine the highest rank in the hand
    private static int highestRank(List<Integer> values) {
        Collections.sort(values);
        return values.get(values.size() - 1);
    }

    // Function to evaluate the hand strength
    private static int evaluateHand(List<String> hand) {
        // Create a map to count the occurrences of each rank
        Map<Character, Integer> rankCount = new HashMap<>();
        List<Integer> values = new ArrayList<>();
        for (String card : hand) {
            char rank = card.charAt(0);
            rankCount.put(rank, rankCount.getOrDefault(rank, 0) + 1);
            values.add(rankValue(rank));
        }

        boolean flush = isFlush(hand);
        boolean straight = isStraight(values);

        // Determine hand strength based on occurrences of ranks
        int pairs = 0;
        int threeOfAKind = 0;
        int fourOfAKind = 0;

        for (int count : rankCount.values()) {
            if (count == 2) pairs++;
            if (count == 3) threeOfAKind++;
            if (count == 4) fourOfAKind++;
        }

        if (straight && flush && highestRank(values) == rankValue('A')) return 9; // Royal flush
        if (straight && flush) return 8; // Straight flush
        if (fourOfAKind > 0) return 7; // Four of a kind
        if (threeOfAKind > 0 && pairs > 0) return 6; // Full house
        if (flush) return 5; // Flush
        if (straight) return 4; // Straight
        if (threeOfAKind > 0) return 3; // Three of a kind
        if (pairs > 1) return 2; // Two pair
        if (pairs > 0) return 1; // One pair
        return 0; // High card
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
        List<String> holeCards = Arrays.asList("AH", "KH");
        List<String> communityCards = Arrays.asList("2H", "3H", "9H");
        int currentBet = 50;
        int potSize = 150;
        int numPlayers = 3;

        try {
            String decision = makeDecision(holeCards, communityCards, currentBet, potSize, numPlayers);
            System.out.println("Decision: " + decision);
        } catch (IllegalArgumentException e) {
            System.out.println(e.getMessage());
        }
    }
}