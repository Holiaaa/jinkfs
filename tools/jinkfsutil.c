#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define END_BOOTLOADER 512
#define END_FILETABLEOFFSET 2560

#pragma pack(push, 1)
typedef struct {   
    uint8_t Signature[3];
    uint8_t DiskLabel[8];
    uint16_t BytesPerBlock;
    uint8_t Reserved;
    uint32_t FileTableOffset;
    uint32_t BlockAreaOffset;
    uint8_t TotalOfEntries;
} JinkFS_Ehdr;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct {   
    uint8_t Name[8];
    uint8_t Extension[3];
    uint8_t Reserved;
    uint32_t Offset;
    uint32_t NumberOfBlocks;
} JinkFS_Entry;
#pragma pack(pop)

int main(int argc, char **argv) {
    printf("JinkFS Disk Utility\n");

    if (argc < 2) {
        printf("usage: %s <JinkFS disk image>\n", argv[0]);
        return -1;
    }

    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        perror("unable to open %s file!\n");
        return -1;
    }

    fseek(f, 0, SEEK_SET);

    char buffer[sizeof(JinkFS_Ehdr)];
    fread(buffer, sizeof(JinkFS_Ehdr), 1, f);

    JinkFS_Ehdr headers;
    memcpy(&headers, buffer, sizeof(buffer));

    char signature[3] = {0xEB, 0x16, 0x4A};
    if (memcmp(signature, headers.Signature, sizeof(signature)) != 0) {
        fprintf(stderr, "%s is not a JinkFS disk! (bad signature)\n", argv[1]);
        fclose(f);
        return -1;
    }

    char diskLabel[9];
    memcpy(&diskLabel, headers.DiskLabel, sizeof(headers.DiskLabel));
    diskLabel[8] = '\0';

    printf("\nDiskLabel\t: %s\n", diskLabel);
    printf("BytesPerBlock\t: %u\n", headers.BytesPerBlock);
    printf("Reserved\t: %u\n", headers.Reserved);
    printf("FileTableOffset\t: %#X\n", headers.FileTableOffset);
    printf("BlockAreaOffset\t: %#X\n", headers.BlockAreaOffset);
    printf("TotalOfEntries\t: %u\n", headers.TotalOfEntries);

    fseek(f, 510, SEEK_SET);
    char bootableBuffer[sizeof(uint16_t)];
    fread(bootableBuffer, sizeof(bootableBuffer), 1, f);

    char bootableSignature[sizeof(uint16_t)] = {0x55, 0xAA};
    if (memcmp(bootableBuffer, bootableSignature, sizeof(bootableBuffer)) == 0) {
        printf("BootableDisk\t: YES\n");
    } else {
        printf("BootableDisk\t: NO\n");
    }

    printf("\nEntries found in the FileEntryTable :\n\n");

    char FileEntryTable[sizeof(JinkFS_Entry) * 128];
    fseek(f, END_BOOTLOADER, SEEK_SET);
    fread(&FileEntryTable, sizeof(FileEntryTable), 1, f);

    int numberOfFile = 0;
    for (int i = 0; i < sizeof(FileEntryTable); i++) {
        JinkFS_Entry entry;
        if (i >= 1) {
            memcpy(&entry, FileEntryTable + i*20, sizeof(JinkFS_Entry));
        } else {
            memcpy(&entry, FileEntryTable, sizeof(JinkFS_Entry));
        }

        if (entry.Name[0] == 0x00) {
            break;
        }

        numberOfFile++;

        char name[9];
        memcpy(&name, entry.Name, sizeof(entry.Name));
        name[8] = '\0';

        printf("NameOfFile\t: [%s]\n", name);

        char ext[4];
        memcpy(&ext, entry.Extension, sizeof(entry.Extension));
        ext[3] = '\0';
        printf("ExtensionOfFile\t: [%s]\n", ext);

        printf("Reserved\t: %u\n", entry.Reserved);
        printf("Offset\t\t: 0x%X\n", entry.Offset);

        char fileContent[((int)entry.NumberOfBlocks)*(int)headers.BytesPerBlock];
        printf("NumberOfBlocks\t: 0x%X (%d B)\n", entry.NumberOfBlocks, sizeof(fileContent));

        printf("\nContent of the file : \n");
        fseek(f, ((int)entry.Offset-(int)0x7C00), SEEK_SET);
        fread(fileContent, sizeof(fileContent), 1, f);

        for (int i = 0; i < sizeof(fileContent); i++) {
            if (fileContent[i] == 0xFFFFFFD6 || (i+1 < sizeof(fileContent) && fileContent[i+1] == 0xFFFFFFD6)) {
                break;
            }
            printf("%02X ", fileContent[i]);
            if ((i + 1) % 32 == 0) printf("\n");
        }

        printf("\n\n");
        printf("----------------------------------\n");
    }

    printf("Totalizing a total of %d files present in the disk.\n", numberOfFile);

    fclose(f);
    return 0;
}
