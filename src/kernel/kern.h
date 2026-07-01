#ifndef KERN_H
#define KERN_H

/* Johnsan kernel core headers */

void kern_init(void);
void kern_sched_start(void);
void kern_sched_run_once(void);
void kern_sched_tick(void);
void kern_mem_init(void);
int kern_ipc_send(int dst, const void *msg, unsigned len);
int kern_ipc_recv(int src, void *msg, unsigned len);
void kern_trap(int num);
int kern_proc_create(void (*entry)(void));
int kern_vfs_mount(const char *dev, const char *path);
long kern_time_ticks(void);

#endif /* KERN_H */
