<?php
require 'vendor/autoload.php';

use Google\Cloud\Firestore\FirestoreClient;

$firestore = new FirestoreClient([
    'projectId' => 'brickswipe-trevor',
]);

$collection = 'sets';
$documentId = 'all_sets';

$jsonFile = 'lego_sets.json';
$jsonData = file_get_contents($jsonFile);
$legoSets = json_decode($jsonData, true);

if (!$legoSets || !is_array($legoSets)) {
    die("Failed to parse JSON.\n");
}

try {
    $firestore->collection($collection)->document($documentId)->set([
        'sets' => $legoSets
    ]);
    echo "Successfully saved sets.\n";
} catch (Exception $e) {
    echo "Error saving document: " . $e->getMessage() . "\n";
}