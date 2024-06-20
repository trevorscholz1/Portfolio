DAILY LOCKZ

Features:
-Backend
-Website
-IOS App

Backend:
    The backend for Daily Lockz is written in Jupyter Notebook with one C file that handles file deletions. The backend is split into three main parts: getting data, parsing the data into a csv, and using the data to train a machine learning model.

    Getting Data:
        Daily Lockz uses web scraping to download box scores with some of the most advanced statistics available and saves them in their corresponding sports data folder.
    Parsing Data:
        Then, the data is parsed into a csv and stored to be used later for training.
    Model:
        Daily Lockz's model and betting algorithm is one of the most advanced and profitable. It uses odds from the-odds-api and will loop through MLB, NFL, NBA, NHL, NCAAB, NCAAF, and Soccer leagues if they are in season. It then will train an XGBoost model to predict each team's upcoming score, each team's upcoming point spread, and each team's upcoming total score. Then, these will be averaged out to come up with the predicted final score for the game. Next, a poisson distribution is used to simulate the game 99,900,000 times to generate probabilties of a team's moneyline, spread, and total score. These probabilities are then compared to the implied probabilties of the sportsbook. If an edge is found, it will display that bet in a dataframe. This algorithm is one of the best at making profit through sports betting, as it gives us positive expected value on each bet, resulting in long term profit.
        
