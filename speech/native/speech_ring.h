// What Ada gives Swift (see Speech.Capture): the microphone's thread puts
// the samples it has heard in the ring that the reader takes them from.
// Nothing in it waits, allocates, or fails. number is the capture's
// session; samples are count 32-bit floats; level is the bits of a float,
// how loud they were, 0...1.
void sp_ring_push(int number, const float *samples, int count, unsigned int level);
