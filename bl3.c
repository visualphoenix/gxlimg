#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>

#include "gxlimg.h"
#include "bl2.h"
#include "bl3.h"
#include "amlcblk.h"
#include "amlsblk.h"

#define FOUT_MODE_DFT (S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP)

/**
 * Sign a BL3 boot image
 *
 * @param fin: Path of BL3 binary input file
 * @param fout: Path of BL3 boot image output file
 * @return: 0 on success, negative number otherwise
 */
int gi_bl3_sign_img(char const *fin, char const *fout)
{
	struct amlsblk asb;
	int fdin = -1, fdout = -1, ret;

	DBG("Sign bl3x %s in %s\n", fin, fout);

	fdin = open(fin, O_RDONLY);
	if(fdin < 0) {
		PERR("Cannot open file %s", fin);
		ret = -errno;
		goto out;
	}

	fdout = open(fout, O_RDWR | O_CREAT, FOUT_MODE_DFT);
	if(fdout < 0) {
		PERR("Cannot open file %s", fout);
		ret = -errno;
		goto out;
	}

	ret = ftruncate(fdout, 0);
	if(ret < 0)
		goto out;

	ret = gi_amlsblk_init(&asb, fdin);
	if(ret < 0)
		goto out;

	ret = gi_amlsblk_hash_payload(&asb, fdin);
	if(ret < 0)
		goto out;

	ret = gi_amlsblk_build_header(&asb);
	if(ret < 0)
		goto out;

	ret = gi_amlsblk_flush_data(&asb, fdin, fdout);
out:
	if(fdout >= 0)
		close(fdout);
	if(fdin >= 0)
		close(fdin);
	return ret;
}

/**
 * Sign a BL30 boot image (two-step: BL2-sign then BL3x-wrap)
 *
 * @param fin: Path of BL30 binary input file
 * @param fout: Path of BL30 boot image output file
 * @return: 0 on success, negative number otherwise
 */
int gi_bl30_sign_img(char const *fin, char const *fout)
{
	char tmppath[] = "/tmp/gxlimg-bl30-XXXXXX";
	int tmpfd, ret;

	tmpfd = mkstemp(tmppath);
	if(tmpfd < 0)
		return -errno;
	close(tmpfd);

	/* Step 1: BL2-format signing */
	ret = gi_bl2_sign_img(fin, tmppath);
	if(ret < 0)
		goto out;

	/* Step 2: BL3x-format wrapping */
	ret = gi_bl3_sign_img(tmppath, fout);

out:
	unlink(tmppath);
	return ret;
}

/**
 * Encrypt a BL3 boot image
 *
 * @param fin: Path of BL3 binary input file
 * @param fout: Path of BL3 boot image output file
 * @return: 0 on success, negative number otherwise
 */
int gi_bl3_encrypt_img(char const *fin, char const *fout)
{
	struct amlcblk acb;
	int fdin = -1, fdout = -1, ret;

	DBG("Encode bl3 %s in %s\n", fin, fout);

	fdin = open(fin, O_RDONLY);
	if(fdin < 0) {
		PERR("Cannot open file %s", fin);
		ret = -errno;
		goto out;
	}

	fdout = open(fout, O_RDWR | O_CREAT, FOUT_MODE_DFT);
	if(fdout < 0) {
		PERR("Cannot open file %s", fout);
		ret = -errno;
		goto out;
	}

	ret = ftruncate(fdout, 0);
	if(ret < 0)
		goto out;

	ret = gi_amlcblk_init(&acb, fdin);
	if(ret < 0)
		goto out;

	ret = gi_amlcblk_aes_enc(&acb, fdout, fdin);
	if(ret < 0)
		goto out;

	ret = gi_amlcblk_dump_hdr(&acb, fdout);
out:
	if(fdout >= 0)
		close(fdout);
	if(fdin >= 0)
		close(fdin);
	return ret;
}

/**
 * Decrypt a BL3 boot image
 *
 * @param fin: Path of BL3 boot image to decode
 * @param fout: Path of result BL3 binary file
 * @return: 0 on success, negative number otherwise
 */
int gi_bl3_decrypt_img(char const *fin, char const *fout)
{
	struct amlcblk acb;
	int fdin = -1, fdout = -1, ret;

	DBG("Decrypt bl3 %s in %s\n", fin, fout);

	fdin = open(fin, O_RDONLY);
	if(fdin < 0) {
		PERR("Cannot open file %s", fin);
		ret = -errno;
		goto out;
	}

	fdout = open(fout, O_WRONLY | O_CREAT, FOUT_MODE_DFT);
	if(fdout < 0) {
		PERR("Cannot open file %s", fout);
		ret = -errno;
		goto out;
	}

	ret = ftruncate(fdout, 0);
	if(ret < 0)
		goto out;

	ret = gi_amlcblk_read_hdr(&acb, fdin);
	if(ret < 0)
		goto out;

	ret = gi_amlcblk_aes_dec(&acb, fdout, fdin);
	if(ret < 0)
		goto out;

out:
	if(fdout >= 0)
		close(fdout);
	if(fdin >= 0)
		close(fdin);
	return ret;
}
