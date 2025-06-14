import { AtSignIcon, LockIcon } from "@chakra-ui/icons";
import {
  Box,
  Button,
  Heading,
  Input,
  InputGroup,
  InputLeftElement,
  VStack,
  FormControl,
  FormLabel,
  useToast,
  Text,
  Flex,
  Icon,
} from "@chakra-ui/react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { login } from "../services/authService";
import { useSetRecoilState } from "recoil";
import { authState } from "../state/authAtom";
import axios from "axios";
import { setAuthTokens } from "../lib/authStore"; // ✅ 추가

export default function Login() {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const setAuth = useSetRecoilState(authState);
  const toast = useToast();
  const navigate = useNavigate();

  const handleLogin = async () => {
    if (!username || !password) {
      toast({
        title: "입력 오류",
        description: "아이디와 비밀번호를 모두 입력하세요.",
        status: "warning",
        duration: 2000,
        isClosable: true,
      });
      return;
    }

    setLoading(true);

    try {
      const { access_token, refresh_token, message } = await login(
        username,
        password
      );

      // ✅ Recoil에 로그인 상태 저장
      setAuth({
        isLoggedIn: true,
        username,
        accessToken: access_token,
        refreshToken: refresh_token,
      });

      // ✅ 전역 상태(authStore)에 토큰 저장 (axios에서 사용)
      setAuthTokens(access_token, refresh_token, username);

      toast({
        title: "로그인 성공",
        description: message,
        status: "success",
        duration: 2000,
        isClosable: true,
      });

      navigate("/dashboard");
    } catch (err: unknown) {
      if (axios.isAxiosError(err)) {
        toast({
          title: "로그인 실패",
          description:
            err.response?.data?.detail?.[0]?.msg || "서버 오류가 발생했습니다.",
          status: "error",
          duration: 2000,
          isClosable: true,
        });
      } else {
        toast({
          title: "알 수 없는 오류",
          description: "예기치 않은 오류가 발생했습니다.",
          status: "error",
          duration: 2000,
          isClosable: true,
        });
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <Flex minH="100vh" align="center" justify="center" bg="gray.900">
      <Box
        bg="white"
        p={10}
        rounded="xl"
        shadow="xl"
        w="full"
        maxW="md"
        textAlign="center"
      >
        <Heading size="lg" mb={2}>
          관리자 로그인
        </Heading>
        <Text mb={6} color="gray.500">
          대시보드에 접근하려면 로그인하세요.
        </Text>

        <VStack spacing={4}>
          <FormControl isRequired>
            <FormLabel>아이디</FormLabel>
            <InputGroup>
              <InputLeftElement pointerEvents="none">
                <Icon as={AtSignIcon} color="gray.400" />
              </InputLeftElement>
              <Input
                placeholder="admin"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
              />
            </InputGroup>
          </FormControl>

          <FormControl isRequired>
            <FormLabel>비밀번호</FormLabel>
            <InputGroup>
              <InputLeftElement pointerEvents="none">
                <Icon as={LockIcon} color="gray.400" />
              </InputLeftElement>
              <Input
                type="password"
                placeholder="••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </InputGroup>
          </FormControl>

          <Button
            colorScheme="teal"
            size="lg"
            w="full"
            mt={4}
            onClick={handleLogin}
            isLoading={loading}
          >
            로그인
          </Button>
        </VStack>
      </Box>
    </Flex>
  );
}
