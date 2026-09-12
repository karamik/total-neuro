// ========================================================================
// puf_signature_ioctl.h – интерфейс драйвера для работы с PUF и подписью
// ========================================================================

#ifndef PUF_SIGNATURE_IOCTL_H
#define PUF_SIGNATURE_IOCTL_H

#include <linux/ioctl.h>
#include <linux/types.h>

#define NEURO_SEC_IOC_MAGIC 'S'

#define NEURO_GET_PUF_ID        _IOR(NEURO_SEC_IOC_MAGIC, 1, struct neuro_puf_id)
#define NEURO_GET_ATTESTATION   _IOR(NEURO_SEC_IOC_MAGIC, 2, __u8)
#define NEURO_GET_SIGNATURE     _IOR(NEURO_SEC_IOC_MAGIC, 3, __u8)
#define NEURO_GET_SECURITY_ALL  _IOR(NEURO_SEC_IOC_MAGIC, 4, struct neuro_security_info)
#define NEURO_TRIGGER_ATTEST    _IO(NEURO_SEC_IOC_MAGIC, 5)
#define NEURO_VERIFY_FIRMWARE   _IOWR(NEURO_SEC_IOC_MAGIC, 6, struct neuro_fw_verify)

struct neuro_puf_id {
    __u32 id_lo;
    __u32 id_mid1;
    __u32 id_mid2;
    __u32 id_hi;
};

struct neuro_security_info {
    struct neuro_puf_id puf_id;
    __u8 shield_ok;
    __u8 chip_unlocked;
    __u8 signature_ok;
    __u8 attestation_ok;
    __u8 zeroize_active;
    __u8 reserved[3];
};

struct neuro_fw_verify {
    __u64 fw_addr;
    __u32 fw_size;
    __u32 result;
};

#endif // PUF_SIGNATURE_IOCTL_H
