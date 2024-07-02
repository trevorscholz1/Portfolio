#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <unistd.h>

int main() {
    char confirm[4];
    char confirm_again[4];
    printf("This program will delete all files in the directory './data/nba_data/scores'.\n");
    printf("Are you sure you want to continue? (yes/no): ");
    scanf("%3s", confirm);

    if (strcmp(confirm, "yes") == 0) {
        printf("Please confirm again by typing 'yes': ");
        scanf("%3s", confirm_again);

        if (strcmp(confirm_again, "yes") == 0) {
            DIR *dir;
            struct dirent *entry;
            char path[256];

            dir = opendir("./data/nba_data/scores");
            if (dir == NULL) {
                printf("Error opening directory.\n");
                return 1;
            }

            while ((entry = readdir(dir)) != NULL) {
                if (entry->d_type == DT_REG) {
                    snprintf(path, sizeof(path), "./data/nba_data/scores%s", entry->d_name);
                    if (remove(path) != 0) {
                        printf("Error deleting file: %s\n", path);
                    }
                }
            }

            closedir(dir);
            printf("All files in './data/nba_data/scores' have been deleted.\n");
        } else {
            printf("Deletion canceled.\n");
        }
    } else {
        printf("Deletion canceled.\n");
    }

    return 0;
}