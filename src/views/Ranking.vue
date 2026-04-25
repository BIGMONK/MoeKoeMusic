<template>
    <RankingContent :player-control="playerControl" />
</template>

<script setup>
import RankingContent from '../components/RankingContent.vue';

defineProps({
    playerControl: Object
});
</script>
