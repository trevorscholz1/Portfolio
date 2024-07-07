#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ftw.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

#define MAX_PATH 1024
#define MAX_SPORT_NAME 10

int remove_file(const char *path, const struct stat *sb, int typeflag, struct FTW *ftwbuf) {
    int result = remove(path);
    if (result) {
        perror(path);
    }
    return result;
}

int delete_directory(const char *dir_path) {
    if (nftw(dir_path, remove_file, 64, FTW_DEPTH | FTW_PHYS) == -1) {
        perror("nftw");
        return 1;
    }
    printf("Directory and its contents deleted successfully: %s\n", dir_path);
    return 0;
}

int create_directory(const char *path) {
    if (mkdir(path, 0777) == -1) {
        if (errno != EEXIST) {
            perror("mkdir");
            return 1;
        }
    }
    printf("Directory created: %s\n", path);
    return 0;
}

int main() {
    char sport[MAX_SPORT_NAME];
    printf("Enter the sport you want to handle: ");
    if (scanf("%9s", sport) != 1) {
        fprintf(stderr, "Failed to read sport input\n");
        return 1;
    }

    char base_path[MAX_PATH];
    snprintf(base_path, sizeof(base_path), "/Users/trevor/trevorscholz1/daily_lockz/models/data");

    char dir_path[MAX_PATH];
    char file_path[MAX_PATH];
    snprintf(dir_path, sizeof(dir_path), "%s/%s_data", base_path, sport);
    snprintf(file_path, sizeof(file_path), "%s/%s_games.csv", base_path, sport);

    const char *paths[] = {dir_path, file_path};
    int num_paths = sizeof(paths) / sizeof(paths[0]);

    for (int i = 0; i < num_paths; i++) {
        struct stat path_stat;
        if (stat(paths[i], &path_stat) == 0) {
            if (S_ISDIR(path_stat.st_mode)) {
                if (delete_directory(paths[i]) != 0) {
                    fprintf(stderr, "Failed to delete directory: %s\n", paths[i]);
                }
            } else {
                if (remove(paths[i]) != 0) {
                    fprintf(stderr, "Failed to delete file: %s\n", paths[i]);
                } else {
                    printf("File deleted successfully: %s\n", paths[i]);
                }
            }
        } else {
            fprintf(stderr, "Failed to get file status: %s\n", paths[i]);
        }
    }

    const char *subdirs[] = {"new_scores", "scores", "standings"};
    int num_subdirs = sizeof(subdirs) / sizeof(subdirs[0]);

    char full_path[MAX_PATH];
    snprintf(full_path, sizeof(full_path), "%s/%s_data", base_path, sport);
    if (create_directory(full_path) != 0) {
        fprintf(stderr, "Failed to create directory: %s\n", full_path);
        return 1;
    }

    for (int i = 0; i < num_subdirs; i++) {
        snprintf(full_path, sizeof(full_path), "%s/%s_data/%s", base_path, sport, subdirs[i]);
        if (create_directory(full_path) != 0) {
            fprintf(stderr, "Failed to create directory: %s\n", full_path);
            return 1;
        }
    }

    printf("All operations completed successfully.\n");
    return 0;
}