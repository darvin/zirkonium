/*
 *  LanBox.cpp
 *  Licht
 *
 *  Created by Chandrasekhar Ramakrishnan on 09.05.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#include "LanBox.h"


static uint16_t g_seqnum;

/* initialize a packet for LC-UDP transmission
 *   iov->iov_base must point to a 1472-byte buffer
 */
void lcu_init(struct iovec *iov) {
	lcu_pkt *pkt = (lcu_pkt *) iov->iov_base;

	pkt->cookie = htons(0xc0b7);
	pkt->seqnum = htons(++g_seqnum);
	iov->iov_len = 4;
}

/* helper function, don't use directly */
uint8_t *lcu_add_dmsg(struct iovec *iov, int start, int len, int id, int cmd) {
	lcu_dmsg *msg;
	size_t offset;

	if (start < 1 || len < 1 || start + len > 65536 || id < 1 || id > 255) {
		errno = EINVAL;
		return NULL;  /* invalid arguments */
	}

	len += 6; /* header */
	if (iov->iov_len + len > 1472) {
		errno = EMSGSIZE;
		return NULL;  /* max packet len exceeded */
	}

	offset = iov->iov_len;
	offset += offset & 1;  /* alignment */

	msg = (lcu_dmsg *) ((char *) iov->iov_base + offset);
	iov->iov_len = offset + len;

	msg->cmd = cmd;
	msg->bufid = id;
	msg->len = htons(len);
	msg->start = htons(start);
	return msg->data;
}

/* add a "publish" message to a packet (to announce data you have)
 *   supply a channel range and the source buffer (typically ID_MIXER)
 *   returns a pointer to where you should put the channel data
 *   returns NULL to indicate failure
 */
uint8_t *lcu_add_publish(struct iovec *iov, int start, int len, int src) {
	return lcu_add_dmsg(iov, start, len, src, 0xC9);
}

/* add a "write" message to a packet (to write data into a remote buffer)
 *   supply a channel range and the target buffer (a layer or ID_MIXER)
 *   returns a pointer to where you should put the channel data
 *   returns NULL to indicate failure
 */
uint8_t *lcu_add_write(struct iovec *iov, int start, int len, int target) {
	return lcu_add_dmsg(iov, start, len, target, 0xCA);
}

