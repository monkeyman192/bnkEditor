# TODO:

### UI

- [x] Add a "back-reference" between an audio in the Audio Explorer and the associated Sound FX.
- [ ] Re-implement the search functionality in the Audio Explorer

### Recompiling BNK's

When recompiling the BNK we will need to consider any changes.

**Options:**

For Audio:
- *Replace* the audio file.
	-> This will not require much other than simply updating the DIDX section.
- *Add* audio file.
	-> This will require some stuff in the HIRC section. May need to merge some data in from another bnk??
	-> If there is no other bnk, we can probably provide a default value.
- *Delete* audio file.
	-> Will require going over the HIRC section and deleting any relevant chunks.
	
For HIRC:
- *Update* values
	-> Simply need to write the updated HIRC chunk with the rest of the bnk back in.