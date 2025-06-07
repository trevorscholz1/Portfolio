import java.util.*;

public class App {
    final static List<String> CARDNUMS = Arrays.asList("2", "3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A");
    final static List<String> CARDSUITS = Arrays.asList("C", "D", "H", "S");

    private static List<String> createDeck() {
        String[] deck = new String[52];

        int i = 0;
        for (String num : CARDNUMS) {
            for (String suit : CARDSUITS) {
                deck[i] = num + suit;
                i++;
            }
        }

        return new ArrayList<>(Arrays.asList(deck));
    }

    private static double runSimulation(List<String> userCards, List<String> communityCards, int numSims) {
        List<String> deck = createDeck();
        deck.removeAll(userCards);
        deck.removeAll(communityCards);

        Collections.shuffle(deck);
        while (communityCards.size() < 5) {
            communityCards.add(deck.getFirst());
            deck.remove(0);
        }

        List<String> opponentCards = new ArrayList<>();
        while (opponentCards.size() < 2) {
            opponentCards.add(deck.getFirst());
            deck.remove(0);
        }

        System.out.println("Community cards:");
        for (String card : communityCards) {
            System.out.println(card);
        }

        System.out.println("Your cards:");
        for (String card : userCards) {
            System.out.println(card);
        }

        System.out.println("Opp cards:");
        for (String card : opponentCards) {
            System.out.println(card);
        }

        double numWins = 0.0;
        if (evaluateHand(userCards.addAll(communityCards)) > evaluateHand(opponentCards.addAll(communityCards))) {
            numWins++;
        }

        return numWins / (double)numSims;
    }

    public static void main(String[] args) {
        List<String> userCards = new ArrayList<>();
        List<String> curCummunityCards = new ArrayList<>();
        boolean canAddCommunity = true;

        Scanner scan = new Scanner(System.in);

        System.out.println("Enter you first card:");
        userCards.add(scan.nextLine());
        System.out.println("Enter your second card");
        userCards.add(scan.nextLine());

        while (canAddCommunity) {
            System.out.println("Enter a community card: (Enter N to stop)");
            String input = scan.nextLine();
            if (input.equals("N")) {
                canAddCommunity = false;
            } else {
                curCummunityCards.add(input);
                if (curCummunityCards.size() >= 5) {
                    canAddCommunity = false;
                }
            }
        }

        scan.close();

        double test = runSimulation(userCards, curCummunityCards, 1);
    }
}