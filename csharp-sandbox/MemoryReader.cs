using System.Runtime.InteropServices;

public class MemoryReader
{
    public static unsafe uint ReadUInt32(UIntPtr address)
    {
        uint result;
        unsafe
        {
            byte* ptr = (byte*)address.ToPointer();
            result = *((uint*)ptr);
        }
        return result;
    }
}
