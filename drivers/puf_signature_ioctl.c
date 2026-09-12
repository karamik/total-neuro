// ========================================================================
// puf_signature_ioctl.c – реализация драйвера для работы с PUF и подписью
// ========================================================================

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/io.h>
#include <linux/uaccess.h>
#include <linux/mutex.h>
#include <linux/delay.h>
#include "puf_signature_ioctl.h"

#define REG_PUF_ID_LO     0x20
#define REG_PUF_ID_MID1   0x24
#define REG_PUF_ID_MID2   0x28
#define REG_PUF_ID_HI     0x2C
#define REG_STATUS        0x00
#define REG_CONTROL       0x04

#define STATUS_DONE        (1 << 0)
#define STATUS_ERROR       (1 << 1)
#define STATUS_NOC_READY   (1 << 3)
#define STATUS_SHIELD_OK   (1 << 4)
#define STATUS_UNLOCKED    (1 << 5)
#define STATUS_SIG_OK      (1 << 6)
#define STATUS_ATTEST_OK   (1 << 7)
#define STATUS_ZEROIZE     (1 << 8)

#define CTRL_PUF_ENABLE    (1 << 4)

extern void __iomem *neuro_base_addr;
extern struct mutex neuro_lock;

static u32 read_reg(u32 offset)
{
    return ioread32(neuro_base_addr + offset);
}

static void write_reg(u32 offset, u32 value)
{
    iowrite32(value, neuro_base_addr + offset);
}

long neuro_sec_ioctl(struct file *filep, unsigned int cmd, unsigned long arg)
{
    int ret = 0;
    struct neuro_puf_id puf_id;
    struct neuro_security_info sec_info;
    struct neuro_fw_verify fw_verify;
    u32 status;
    u8 flag;

    if (!neuro_base_addr)
        return -ENODEV;

    mutex_lock(&neuro_lock);

    switch (cmd) {
    case NEURO_GET_PUF_ID:
        write_reg(REG_CONTROL, read_reg(REG_CONTROL) | CTRL_PUF_ENABLE);
        mdelay(1);
        puf_id.id_lo   = read_reg(REG_PUF_ID_LO);
        puf_id.id_mid1 = read_reg(REG_PUF_ID_MID1);
        puf_id.id_mid2 = read_reg(REG_PUF_ID_MID2);
        puf_id.id_hi   = read_reg(REG_PUF_ID_HI);
        if (puf_id.id_lo == 0 && puf_id.id_mid1 == 0 &&
            puf_id.id_mid2 == 0 && puf_id.id_hi == 0) {
            ret = -EIO;
            break;
        }
        if (copy_to_user((void __user *)arg, &puf_id, sizeof(puf_id)))
            ret = -EFAULT;
        break;

    case NEURO_GET_ATTESTATION:
        status = read_reg(REG_STATUS);
        flag = (status & STATUS_ATTEST_OK) ? 1 : 0;
        if (copy_to_user((void __user *)arg, &flag, sizeof(flag)))
            ret = -EFAULT;
        break;

    case NEURO_GET_SIGNATURE:
        status = read_reg(REG_STATUS);
        flag = (status & STATUS_SIG_OK) ? 1 : 0;
        if (copy_to_user((void __user *)arg, &flag, sizeof(flag)))
            ret = -EFAULT;
        break;

    case NEURO_GET_SECURITY_ALL:
        write_reg(REG_CONTROL, read_reg(REG_CONTROL) | CTRL_PUF_ENABLE);
        mdelay(1);
        sec_info.puf_id.id_lo   = read_reg(REG_PUF_ID_LO);
        sec_info.puf_id.id_mid1 = read_reg(REG_PUF_ID_MID1);
        sec_info.puf_id.id_mid2 = read_reg(REG_PUF_ID_MID2);
        sec_info.puf_id.id_hi   = read_reg(REG_PUF_ID_HI);
        status = read_reg(REG_STATUS);
        sec_info.shield_ok      = (status & STATUS_SHIELD_OK) ? 1 : 0;
        sec_info.chip_unlocked  = (status & STATUS_UNLOCKED)  ? 1 : 0;
        sec_info.signature_ok   = (status & STATUS_SIG_OK)    ? 1 : 0;
        sec_info.attestation_ok = (status & STATUS_ATTEST_OK) ? 1 : 0;
        sec_info.zeroize_active = (status & STATUS_ZEROIZE)   ? 1 : 0;
        sec_info.reserved[0] = sec_info.reserved[1] = sec_info.reserved[2] = 0;
        if (copy_to_user((void __user *)arg, &sec_info, sizeof(sec_info)))
            ret = -EFAULT;
        break;

    case NEURO_TRIGGER_ATTEST:
        write_reg(REG_CONTROL, read_reg(REG_CONTROL) | CTRL_PUF_ENABLE);
        mdelay(5);
        status = read_reg(REG_STATUS);
        if (!(status & STATUS_ATTEST_OK))
            ret = -EIO;
        break;

    case NEURO_VERIFY_FIRMWARE:
        if (copy_from_user(&fw_verify, (void __user *)arg, sizeof(fw_verify))) {
            ret = -EFAULT;
            break;
        }
        status = read_reg(REG_STATUS);
        if (!(status & STATUS_DONE))
            fw_verify.result = 0;
        else if (status & STATUS_SIG_OK)
            fw_verify.result = 1;
        else
            fw_verify.result = 2;
        if (copy_to_user((void __user *)arg, &fw_verify, sizeof(fw_verify)))
            ret = -EFAULT;
        break;

    default:
        ret = -ENOTTY;
        break;
    }

    mutex_unlock(&neuro_lock);
    return ret;
}

EXPORT_SYMBOL(neuro_sec_ioctl);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("TOTAL-Neuro Team");
MODULE_DESCRIPTION("PUF and Firmware Signature IOCTL driver");
MODULE_VERSION("1.0");
