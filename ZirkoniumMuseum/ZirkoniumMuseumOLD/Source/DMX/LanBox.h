/*
 *  LanBox.h
 *  Licht
 *
 *  Created by Chandrasekhar Ramakrishnan on 09.05.07.
 *  Copyright 2007 C. Ramakrishnan/ZKM. All rights reserved.
 *
 */

#ifndef __LanBox_H__
#define __LanBox_H__

#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <sys/uio.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


// Structures and functions provided by the makers of the LanBox.

/* buffer ids */
#define ID_LAYER_A  (1)	/* A..Z = 1..26, AA..AZ = 27..52, BA..BK = 53..63 */
#define ID_DMXOUT (255) /* DMX output buffer (publish-only) */
#define ID_MIXER  (254) /* Mixer buffer */
#define ID_DMXIN  (253) /* DMX input buffer (publish-only) */
#define ID_EXTIN  (252) /* External inputs buffer (publish-only) */

#define LCUDP_BUFSZ (1472)

typedef struct lcu_pkt lcu_pkt;
typedef struct lcu_dmsg lcu_dmsg;

struct lcu_pkt {
	uint16_t cookie;
	uint16_t seqnum;
};

struct lcu_dmsg { /* data (publish/write) message format */
	uint8_t  cmd;
	uint8_t  bufid;
	uint16_t len;
	uint16_t start;
	uint8_t  data[1];  /* data[len-6] */
};

/* initialize a packet for LC-UDP transmission
 *   iov->iov_base must point to a 1472-byte buffer
 */
void lcu_init(struct iovec *iov);

/* add a "publish" message to a packet (to announce data you have)
 *   supply a channel range and the source buffer (typically ID_MIXER)
 *   returns a pointer to where you should put the channel data
 *   returns NULL to indicate failure
 */
uint8_t *lcu_add_publish(struct iovec *iov, int start, int len, int src);

/* add a "write" message to a packet (to write data into a remote buffer)
 *   supply a channel range and the target buffer (a layer or ID_MIXER)
 *   returns a pointer to where you should put the channel data
 *   returns NULL to indicate failure
 */
uint8_t *lcu_add_write(struct iovec *iov, int start, int len, int target);


#endif