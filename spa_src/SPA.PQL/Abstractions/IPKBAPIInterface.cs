using System.Runtime.InteropServices;
using SPA.PQL.API;
using SPA.PQL.Elements;

namespace SPA.PQL.Abstractions {
    public interface IPKBInterface {
        List<ProgramElement> Init(string path);
        bool Parent(uint s1_type, uint s1, uint s2_type, uint s2);
        bool Follow(uint s1_type, uint s1, uint s2_type, uint s2);
        bool Uses(uint s1_type, uint s1, uint s2_type, uint s2);
        bool Modifies(uint stmt, string varName);
        void DeInit();
        bool ParentTransitive(uint s1_type, uint s1, uint s2_type, uint s2);
        bool FollowsTransitive(uint s1_type, uint s1, uint s2_type, uint s2);
        string? GetVariableName(uint valueId);
        bool ModifiesProc(string procName, string varName);
        string? GetProcedureName(uint valueId);
    }

    public sealed class PKBInterface : IPKBInterface {
        public List<ProgramElement> Init(string path)
        {
            var errCode = SpaApi.Init(path);
            if (errCode != 0)
            {
                var pointer = SpaApi.GetErrorMessage();
                throw new ArgumentException(Marshal.PtrToStringAnsi(pointer));
            }

            var result = new List<ProgramElement>();

            uint i = 0;
            while (true)
            {
                var temp = SpaApi.GetNode(i);

                if (temp.type == 0)
                    break;
                var type = (SpaApi.StatementType)temp.type;
                result.Add(new ProgramElement()
                {
                    Type = type,
                    LineNumber = temp.line_no,
                    StatementNumber = temp.statement_id,
                    ValueId = temp.value_id,
                });

                if (type == SpaApi.StatementType.ASSIGN && !result.Any(x => x.Type == SpaApi.StatementType.VAR && x.ValueId == temp.value_id))
                {
                    result.Add(new ProgramElement()
                    {
                        Type = SpaApi.StatementType.VAR,
                        LineNumber = temp.line_no,
                        StatementNumber = 0,
                        ValueId = temp.value_id,
                    });
                }

                i++;
            }

            return result;
        }

        public bool Parent(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            var pointer = SpaApi.Parent(s1_type, s1, "", s2_type, s2, "");

            if (pointer == 0)
                return false;

            return Marshal.ReadByte(unchecked((IntPtr)(long)(ulong)pointer)) > 0 && SpaApi.GetResultSize() > 0;
        }

        public bool ParentTransitive(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            var pointer = SpaApi.ParentTransitive(s1_type, s1, "", s2_type, s2, "");

            if (pointer == 0)
                return false;

            return Marshal.ReadByte(unchecked((IntPtr)(long)(ulong)pointer)) > 0 && SpaApi.GetResultSize() > 0;
        }

        public bool Follow(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            if (s1_type == s2_type && s1 == s2)
                return false;
            
            var pointer = SpaApi.Follows(s1_type, s1, "", s2_type, s2, "");

            if (pointer == 0)
                return false;

            var value = (uint)Marshal.ReadInt32(unchecked((IntPtr)(long)(ulong)pointer));

            return (uint)Marshal.ReadInt32(unchecked((IntPtr)(long)(ulong)pointer)) > 0 && SpaApi.GetResultSize() > 0;
        }

        public bool FollowsTransitive(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            if (s1_type == s2_type && s1 == s2)
                return false;

            var pointer = SpaApi.FollowsTransitive(s1_type, s1, "", s2_type, s2, "");

            if (pointer == 0)
                return false;

            return (uint)Marshal.ReadInt32(unchecked((IntPtr)(long)(ulong)pointer)) > 0 && SpaApi.GetResultSize() > 0;
        }

        public string? GetVariableName(uint valueId)
        {
            var pointer = SpaApi.GetVarName(valueId);

            return Marshal.PtrToStringAnsi(pointer);
        }

        public bool ModifiesProc(string procName, string varName)
        {
            var pointer = SpaApi.ModifiesProc(procName, varName);

            if (pointer == 0)
                return false;

            return (uint)Marshal.ReadInt32(unchecked((IntPtr)(long)(ulong)pointer)) > 0 && SpaApi.GetResultSize() > 0;
        }

        public string? GetProcedureName(uint valueId)
        {
            var pointer = SpaApi.GetProcName(valueId);

            return Marshal.PtrToStringAnsi(pointer);
        }

        public bool Uses(uint s1_type, uint s1, uint s2_type, uint s2)
        {
            throw new NotImplementedException();
        }

        public bool Modifies(uint stmt, string varName)
        {
            var pointer = SpaApi.Modifies(stmt, varName);

            if (pointer == 0)
                return false;

            return (uint)Marshal.ReadInt32(unchecked((IntPtr)(long)(ulong)pointer)) > 0 && SpaApi.GetResultSize() > 0;
        }

        public void DeInit()
        {
            var errCode = SpaApi.Deinit();

            if (errCode != 0)
            {
                var pointer = SpaApi.GetErrorMessage();
                var message = Marshal.PtrToStringAnsi(pointer);
                throw new InvalidOperationException(message);
            }
        }
    }
}